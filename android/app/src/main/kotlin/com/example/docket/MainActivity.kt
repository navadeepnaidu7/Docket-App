package com.example.docket

import android.graphics.Bitmap
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.util.Base64
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

                // Check NFC
                if (nfcAdapter == null || !nfcAdapter!!.isEnabled) {
                    result.error("NFC_UNAVAILABLE", "NFC is not available or enabled", null)
                    return@setMethodCallHandler
                }

                if (isScanning) {
                    result.error("BUSY", "An NFC scan is already in progress", null)
                    return@setMethodCallHandler
                }
                scanResult = result
                isScanning = true

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

    private fun stopNfcScanning() {
        if (!isScanning) return
        isScanning = false
        bacKey = null
        nfcAdapter?.disableReaderMode(this)
    }

    override fun onPause() {
        stopNfcScanning()
        super.onPause()
    }

    override fun onTagDiscovered(tag: Tag?) {
        if (!isScanning || tag == null) return

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
                    passportService.doBAC(bacKey)
                    bacAuthSuccess = true
                } catch (e: Exception) {
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

                    // Prepare response
                    val response = HashMap<String, Any?>()
                    response["firstName"] = mrzInfo.secondaryIdentifier?.replace("<", " ")?.trim()
                    response["lastName"] = mrzInfo.primaryIdentifier?.replace("<", " ")?.trim()
                    response["nationality"] = mrzInfo.nationality
                    response["documentNumber"] = mrzInfo.documentNumber
                    response["gender"] = mrzInfo.gender.toString()
                    response["dateOfBirth"] = mrzInfo.dateOfBirth
                    response["dateOfExpiry"] = mrzInfo.dateOfExpiry
                    response["issuingState"] = mrzInfo.issuingState
                    response["documentCode"] = mrzInfo.documentCode
                    response["photoBase64"] = photoBase64

                    // Read DG11 (Additional Personal Details - Optional)
                    try {
                        val dg11In = passportService.getInputStream(PassportService.EF_DG11)
                        val dg11File = DG11File(dg11In)
                        response["dg11_fullName"] = dg11File.nameOfHolder
                        response["dg11_personalNumber"] = dg11File.personalNumber
                        response["dg11_placeOfBirth"] = dg11File.placeOfBirth?.joinToString(", ")
                        response["dg11_permanentAddress"] = dg11File.permanentAddress?.joinToString(", ")
                        response["dg11_telephone"] = dg11File.telephone
                        response["dg11_profession"] = dg11File.profession
                        response["dg11_title"] = dg11File.title
                        response["dg11_personalSummary"] = dg11File.personalSummary
                        response["dg11_custodyInformation"] = dg11File.custodyInformation
                    } catch (e: Exception) {
                        response["dg11_status"] = "Not Present or Read Error"
                    }

                    // Read DG12 (Document Details - Optional)
                    try {
                        val dg12In = passportService.getInputStream(PassportService.EF_DG12)
                        val dg12File = DG12File(dg12In)
                        response["dg12_issuingAuthority"] = dg12File.issuingAuthority
                        response["dg12_dateOfIssue"] = dg12File.dateOfIssue
                        response["dg12_endorsementsAndObservations"] = dg12File.endorsementsAndObservations
                        response["dg12_taxOrExitRequirements"] = dg12File.taxOrExitRequirements
                        response["dg12_dateAndTimeOfPersonalization"] = dg12File.dateAndTimeOfPersonalization
                        response["dg12_personalizationSystemSerialNumber"] = dg12File.personalizationSystemSerialNumber
                    } catch (e: Exception) {
                        response["dg12_status"] = "Not Present or Read Error"
                    }

                    withContext(Dispatchers.Main) {
                        scanResult?.success(response)
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
            scanResult?.error(code, message, null)
            stopNfcScanning()
        }
    }
}
