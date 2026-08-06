package com.example.docket

import android.graphics.Bitmap
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.sf.scuba.smartcards.CardService
import org.jmrtd.BACKey
import org.jmrtd.PassportService
import org.jmrtd.lds.icao.DG1File
import org.jmrtd.lds.icao.DG2File
import org.jmrtd.lds.icao.DG11File
import org.jmrtd.lds.icao.DG12File
import java.io.ByteArrayOutputStream
import com.gemalto.jp2.JP2Decoder

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {

    private val CHANNEL = "com.docket/nfc_passport"

    // Lifecycle only. Never log document numbers, dates, MRZ or chip
    // payloads -- these are somebody's identity documents.
    private val TAG = "DocketNfc"
    private val YYMMDD = Regex("^\\d{6}$")
    private var nfcAdapter: NfcAdapter? = null
    
    private var isScanning = false
    private var scanResult: MethodChannel.Result? = null
    private var bacKey: BACKey? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startNfcRead") {
                val passportNumber = call.argument<String>("passportNumber") ?: ""
                val dateOfBirth = call.argument<String>("dateOfBirth") ?: ""
                val expiryDate = call.argument<String>("expiryDate") ?: ""

                if (passportNumber.isEmpty() || dateOfBirth.isEmpty() || expiryDate.isEmpty()) {
                    result.error("INVALID_ARGS", "Passport details for BAC missing", null)
                    return@setMethodCallHandler
                }

                // BAC dates are YYMMDD. Reject anything else here rather than
                // letting the chip fail opaquely six APDUs later.
                if (!dateOfBirth.matches(YYMMDD) || !expiryDate.matches(YYMMDD)) {
                    result.error(
                        "INVALID_ARGS",
                        "Dates for BAC must be YYMMDD",
                        null
                    )
                    return@setMethodCallHandler
                }

                // Check NFC
                if (nfcAdapter == null || !nfcAdapter!!.isEnabled) {
                    result.error("NFC_UNAVAILABLE", "NFC is not available or enabled", null)
                    return@setMethodCallHandler
                }

                if (isScanning) {
                    result.error("BUSY", "An NFC scan is already in progress", null)
                    return@setMethodCallHandler
                }

                // Build the key from the three values the caller sent. Built
                // after the guards so an early return cannot leave a key behind
                // for a scan that never started.
                //
                // This assignment is the whole reason chip reads never worked:
                // bacKey was declared, nulled on stop, and handed to doBAC, but
                // never actually built. Every read threw inside doBAC(null) and
                // surfaced as a generic BAC failure, so the e-passport path
                // could not succeed even once.
                bacKey = BACKey(passportNumber.trim().uppercase(), dateOfBirth, expiryDate)

                scanResult = result
                isScanning = true
                Log.i(TAG, "startNfcRead: reader mode on, awaiting tag")

                // Enable Reader Mode
                val options = Bundle()
                options.putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
                nfcAdapter?.enableReaderMode(
                    this,
                    this,
                    NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
                    options
                )
            } else if (call.method == "stopNfcRead") {
                stopNfcScanning()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Stops reader mode and settles any pending Dart call.
     *
     * The pending MethodChannel.Result used to be abandoned here, so backing
     * out mid-read left the awaiting Dart future hanging forever. Replying
     * CANCELLED and clearing the field also prevents a second reply landing on
     * an already-completed result, which throws "Reply already submitted".
     */
    private fun stopNfcScanning() {
        if (!isScanning) return
        isScanning = false
        bacKey = null
        nfcAdapter?.disableReaderMode(this)

        // No-op when something already answered (a successful read, or an
        // error). Only a genuinely abandoned scan gets CANCELLED.
        replyOnce { it.error("CANCELLED", "Scan cancelled", null) }
    }

    override fun onPause() {
        stopNfcScanning()
        super.onPause()
    }

    override fun onDestroy() {
        stopNfcScanning()
        super.onDestroy()
    }

    override fun onTagDiscovered(tag: Tag?) {
        if (!isScanning || tag == null) return

        Log.i(TAG, "onTagDiscovered")
        val isoDep = IsoDep.get(tag)
        if (isoDep == null) {
            sendError("ISO_DEP_NOT_SUPPORTED", "Tag does not support IsoDep")
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                isoDep.timeout = 10000 // 10 seconds for APDU operations
                val cardService = CardService.getInstance(isoDep)
                cardService.open()

                val passportService = PassportService(
                    cardService,
                    PassportService.NORMAL_MAX_TRANCEIVE_LENGTH,
                    PassportService.DEFAULT_MAX_BLOCKSIZE,
                    false,
                    false
                )
                passportService.open()

                // Perform BAC
                var bacAuthSuccess = false
                try {
                    passportService.sendSelectApplet(false)
                    val key = bacKey
                    if (key == null) {
                        sendError("INVALID_ARGS", "No BAC key for this scan")
                        return@launch
                    }
                    passportService.doBAC(key)
                    bacAuthSuccess = true
                    Log.i(TAG, "BAC succeeded")
                } catch (e: Exception) {
                    Log.w(TAG, "BAC failed: ${e.javaClass.simpleName}")
                    sendError("BAC_FAILED", "Basic Access Control failed: ${e.message}")
                    return@launch
                }

                if (bacAuthSuccess) {
                    // Read DG1 (MRZ data)
                    val dg1In = passportService.getInputStream(PassportService.EF_DG1)
                    val dg1File = DG1File(dg1In)
                    val mrzInfo = dg1File.mrzInfo

                    // Read DG2 (Photo)
                    var photoBase64: String? = null
                    try {
                        val dg2In = passportService.getInputStream(PassportService.EF_DG2)
                        val dg2File = DG2File(dg2In)
                        val faceInfos = dg2File.faceInfos
                        if (faceInfos.isNotEmpty()) {
                            val faceInfo = faceInfos[0]
                            val imageInfos = faceInfo.faceImageInfos
                            if (imageInfos.isNotEmpty()) {
                                val imageInfo = imageInfos[0]
                                val imageLength = imageInfo.imageLength
                                val dataInputStream = imageInfo.imageInputStream
                                val imageData = ByteArray(imageLength)
                                java.io.DataInputStream(dataInputStream).readFully(imageData)

                                // Convert JP2 to Bitmap if needed, or if it's JPEG
                                val mimeType = imageInfo.mimeType ?: ""
                                if (mimeType.contains("jp2", ignoreCase = true) || mimeType.contains("jpeg2000", ignoreCase = true)) {
                                    val bitmap = JP2Decoder(imageData).decode()
                                    val stream = ByteArrayOutputStream()
                                    bitmap.compress(Bitmap.CompressFormat.JPEG, 100, stream)
                                    photoBase64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                                } else {
                                    // standard jpeg
                                    photoBase64 = Base64.encodeToString(imageData, Base64.NO_WRAP)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    // Prepare response. Only non-null, non-blank values are
                    // put in the map — Dart's Map.from used to receive null
                    // photo/place-of-birth entries that then never made it
                    // onto the card when the save path also dropped them.
                    val response = HashMap<String, Any>()
                    fun put(key: String, value: Any?) {
                        when (value) {
                            null -> return
                            is String -> if (value.isNotBlank()) response[key] = value.trim()
                            else -> response[key] = value
                        }
                    }

                    put("firstName", mrzInfo.secondaryIdentifier?.replace("<", " ")?.trim())
                    put("lastName", mrzInfo.primaryIdentifier?.replace("<", " ")?.trim())
                    put("nationality", mrzInfo.nationality)
                    // MRZ document numbers are left-aligned and may be padded
                    // with '<' to 9 characters; the card should not show them.
                    put("documentNumber", mrzInfo.documentNumber?.replace("<", "")?.trim())
                    // Enum name is MALE/FEMALE/UNKNOWN; Dart normalises to M/F/X.
                    put("gender", mrzInfo.gender?.name ?: mrzInfo.gender?.toString())
                    put("dateOfBirth", mrzInfo.dateOfBirth)
                    put("dateOfExpiry", mrzInfo.dateOfExpiry)
                    put("issuingState", mrzInfo.issuingState)
                    put("documentCode", mrzInfo.documentCode)
                    if (!photoBase64.isNullOrBlank()) {
                        response["photoBase64"] = photoBase64
                    }

                    // Read DG11 (Additional Personal Details - Optional)
                    try {
                        val dg11In = passportService.getInputStream(PassportService.EF_DG11)
                        val dg11File = DG11File(dg11In)
                        put("dg11_fullName", dg11File.nameOfHolder)
                        put("dg11_personalNumber", dg11File.personalNumber)
                        put(
                            "dg11_placeOfBirth",
                            dg11File.placeOfBirth
                                ?.mapNotNull { it?.trim() }
                                ?.filter { it.isNotEmpty() }
                                ?.joinToString(", ")
                        )
                        put(
                            "dg11_permanentAddress",
                            dg11File.permanentAddress
                                ?.mapNotNull { it?.trim() }
                                ?.filter { it.isNotEmpty() }
                                ?.joinToString(", ")
                        )
                        put("dg11_telephone", dg11File.telephone)
                        put("dg11_profession", dg11File.profession)
                        put("dg11_title", dg11File.title)
                        put("dg11_personalSummary", dg11File.personalSummary)
                        put("dg11_custodyInformation", dg11File.custodyInformation)
                    } catch (e: Exception) {
                        Log.i(TAG, "DG11 not present or unreadable")
                    }

                    // Read DG12 (Document Details - Optional)
                    try {
                        val dg12In = passportService.getInputStream(PassportService.EF_DG12)
                        val dg12File = DG12File(dg12In)
                        put("dg12_issuingAuthority", dg12File.issuingAuthority)
                        put("dg12_dateOfIssue", dg12File.dateOfIssue)
                        put("dg12_endorsementsAndObservations", dg12File.endorsementsAndObservations)
                        put("dg12_taxOrExitRequirements", dg12File.taxOrExitRequirements)
                        put("dg12_dateAndTimeOfPersonalization", dg12File.dateAndTimeOfPersonalization)
                        put("dg12_personalizationSystemSerialNumber", dg12File.personalizationSystemSerialNumber)
                    } catch (e: Exception) {
                        Log.i(TAG, "DG12 not present or unreadable")
                    }

                    Log.i(
                        TAG,
                        "chip read ok: keys=${response.keys.sorted()} photo=${response.containsKey("photoBase64")}"
                    )

                    withContext(Dispatchers.Main) {
                        replyOnce { it.success(response) }
                        stopNfcScanning()
                    }
                }
            } catch (e: Exception) {
                sendError("NFC_READ_ERROR", e.message ?: "Unknown error")
            }
        }
    }

    private fun sendError(code: String, message: String) {
        CoroutineScope(Dispatchers.Main).launch {
            replyOnce { it.error(code, message, null) }
            stopNfcScanning()
        }
    }

    /**
     * Answers the pending Dart call, at most once.
     *
     * A MethodChannel.Result may be replied to exactly once; a second reply
     * throws IllegalStateException and takes the whole app down. Three paths
     * can reach a reply here -- success, sendError, and the CANCELLED from
     * stopNfcScanning -- and the success path calls stopNfcScanning
     * immediately afterwards, so it crashed on every successful chip read.
     *
     * Taking the result and clearing the field before replying makes the
     * second caller a no-op instead of a crash.
     */
    private fun replyOnce(reply: (MethodChannel.Result) -> Unit) {
        val pending = scanResult ?: return
        scanResult = null
        reply(pending)
    }
}
