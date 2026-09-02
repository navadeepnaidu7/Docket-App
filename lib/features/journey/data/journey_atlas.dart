import 'dart:math' as math;
import 'dart:typed_data';

/// The decoded globe atlas: land dots and boundary rings, as unit vectors.
///
/// Positions are kept as precomputed unit vectors rather than latitude and
/// longitude. That trades roughly 140KB of memory for removing two trig calls
/// per dot per frame, and with twelve thousand dots at sixty frames a second it
/// is the difference between shipping and not.
final class JourneyAtlas {
  const JourneyAtlas({
    required this.dotX,
    required this.dotY,
    required this.dotZ,
    required this.bandOffsets,
    required this.ringX,
    required this.ringY,
    required this.ringZ,
    required this.ringStarts,
    required this.ringLengths,
  });

  /// An atlas with no geometry.
  ///
  /// What the globe falls back to when the asset is missing or corrupt: it still
  /// draws its rim, its arcs and its markers, and still tells the truth about
  /// where you have been. It just has no continents.
  static final JourneyAtlas wireframe = JourneyAtlas(
    dotX: Float32List(0),
    dotY: Float32List(0),
    dotZ: Float32List(0),
    bandOffsets: Int32List(0),
    ringX: Float32List(0),
    ringY: Float32List(0),
    ringZ: Float32List(0),
    ringStarts: Int32List(0),
    ringLengths: Int32List(0),
  );

  final Float32List dotX;
  final Float32List dotY;
  final Float32List dotZ;

  /// Cumulative end index per level-of-detail band, coarsest first.
  ///
  /// Bands are contiguous prefixes, so drawing detail level `n` means slicing
  /// `[0, bandOffsets[n])` rather than filtering the whole field.
  final Int32List bandOffsets;

  final Float32List ringX;
  final Float32List ringY;
  final Float32List ringZ;
  final Int32List ringStarts;
  final Int32List ringLengths;

  int get dotCount => dotX.length;

  int get ringCount => ringLengths.length;

  bool get isEmpty => dotCount == 0 && ringCount == 0;

  /// Number of dots to draw at a given detail level, clamped to what exists.
  int dotsForBand(int band) {
    if (bandOffsets.isEmpty) return 0;
    final int index = band.clamp(0, bandOffsets.length - 1);
    return bandOffsets[index];
  }
}

const int _magic = 0x414A4B44; // 'DKJA'
const int _supportedVersion = 1;
const double _latScale = 90.0 / 32767.0;
const double _lngScale = 180.0 / 32767.0;

/// Decodes the packed atlas. The `compute` entry point.
///
/// Top-level and taking a single argument so it can run through `compute`,
/// matching the one existing isolate pattern in this repo
/// (`lib/core/storage/attachment_store.dart`). Decoding is only a few
/// milliseconds, but it lands on the frame the user taps Journey, and that is
/// the one frame that must not jank.
JourneyAtlas decodeJourneyAtlas(Uint8List bytes) {
  final ByteData data = ByteData.view(
    bytes.buffer,
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );

  if (bytes.lengthInBytes < 36) {
    throw const FormatException('Journey atlas is too short to be valid');
  }
  if (data.getUint32(0, Endian.little) != _magic) {
    throw const FormatException('Journey atlas has a bad magic number');
  }
  final int version = data.getUint16(4, Endian.little);
  if (version != _supportedVersion) {
    throw FormatException('Journey atlas version $version is not supported');
  }

  // Verify before trusting any offset in the file. A truncated or partially
  // written asset otherwise decodes into a plausible-looking but wrong planet,
  // which is exactly the failure a checksum is cheap insurance against.
  final int declaredCrc =
      data.getUint32(bytes.lengthInBytes - 4, Endian.little);
  final int actualCrc = _crc32(bytes, 0, bytes.lengthInBytes - 4);
  if (declaredCrc != actualCrc) {
    throw const FormatException('Journey atlas failed its checksum');
  }

  int offset = 8;
  final int dotCount = data.getUint32(offset, Endian.little);
  offset += 4;
  final int bandCount = data.getUint8(offset);
  offset += 4; // one byte plus three of padding

  final Int32List bandOffsets = Int32List(bandCount);
  for (int i = 0; i < bandCount; i++) {
    bandOffsets[i] = data.getUint32(offset, Endian.little);
    offset += 4;
  }

  final int cellCount = data.getUint32(offset, Endian.little);
  offset += 4 + cellCount * 4; // reserved spatial index, empty in v1

  final Float32List dotX = Float32List(dotCount);
  final Float32List dotY = Float32List(dotCount);
  final Float32List dotZ = Float32List(dotCount);
  final int lngBase = offset + dotCount * 2;
  for (int i = 0; i < dotCount; i++) {
    final double lat = data.getInt16(offset + i * 2, Endian.little) * _latScale;
    final double lng = data.getInt16(lngBase + i * 2, Endian.little) * _lngScale;
    _writeUnitVector(lat, lng, i, dotX, dotY, dotZ);
  }
  offset = lngBase + dotCount * 2;

  final int ringCount = data.getUint32(offset, Endian.little);
  offset += 4;

  final Int32List ringLengths = Int32List(ringCount);
  int vertexTotal = 0;
  for (int i = 0; i < ringCount; i++) {
    final int length = data.getUint16(offset + i * 2, Endian.little);
    ringLengths[i] = length;
    vertexTotal += length;
  }
  offset += ringCount * 2;

  final Int32List ringStarts = Int32List(ringCount);
  int running = 0;
  for (int i = 0; i < ringCount; i++) {
    ringStarts[i] = running;
    running += ringLengths[i];
  }

  final Float32List ringX = Float32List(vertexTotal);
  final Float32List ringY = Float32List(vertexTotal);
  final Float32List ringZ = Float32List(vertexTotal);
  final int ringLngBase = offset + vertexTotal * 2;
  for (int i = 0; i < vertexTotal; i++) {
    final double lat = data.getInt16(offset + i * 2, Endian.little) * _latScale;
    final double lng =
        data.getInt16(ringLngBase + i * 2, Endian.little) * _lngScale;
    _writeUnitVector(lat, lng, i, ringX, ringY, ringZ);
  }

  return JourneyAtlas(
    dotX: dotX,
    dotY: dotY,
    dotZ: dotZ,
    bandOffsets: bandOffsets,
    ringX: ringX,
    ringY: ringY,
    ringZ: ringZ,
    ringStarts: ringStarts,
    ringLengths: ringLengths,
  );
}

/// Y-up unit vector, matching `unitVectorFor` in the domain layer.
void _writeUnitVector(
  double latDeg,
  double lngDeg,
  int index,
  Float32List xs,
  Float32List ys,
  Float32List zs,
) {
  const double degToRad = math.pi / 180.0;
  final double lat = latDeg * degToRad;
  final double lng = lngDeg * degToRad;
  final double cosLat = math.cos(lat);
  xs[index] = cosLat * math.cos(lng);
  ys[index] = math.sin(lat);
  zs[index] = cosLat * math.sin(lng);
}

/// CRC-32, matching Python's `zlib.crc32` so the generator and the decoder
/// agree without pulling in a package for thirty lines of table lookup.
int _crc32(Uint8List bytes, int start, int end) {
  int crc = 0xFFFFFFFF;
  for (int i = start; i < end; i++) {
    crc ^= bytes[i];
    for (int bit = 0; bit < 8; bit++) {
      final int mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return (~crc) & 0xFFFFFFFF;
}
