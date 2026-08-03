/// Matches a base64 body: the standard alphabet plus optional wrapping
/// whitespace, with at most the two permitted '=' pad characters at the end.
final RegExp _base64Body = RegExp(r'^[A-Za-z0-9+/\s]+={0,2}$');

/// Tells a base64 image payload apart from a filesystem path.
///
/// Document records historically kept both kinds of value in a single
/// `imagePath` field: the MRZ scanner wrote the path of the captured photo,
/// while the NFC chip read wrote a base64-encoded DG2 portrait. Anything
/// rendering that field had to guess which it had, and the passport card did
/// not guess at all — it called `base64Decode` unconditionally and threw on
/// every scanned record.
///
/// New records split the two (see `PassportProfile.photoBase64`), so this is
/// only needed to migrate records written before that split.
///
/// Classification is by *character set*, not by leading character. The earlier
/// ID-side rule rejected anything starting with '/', which silently misfiled
/// every JPEG: base64 of the JPEG magic bytes `FF D8 FF` is `/9j/`, so an
/// encoded photo always starts with a slash. A filesystem path is excluded by
/// its extension dot and separators instead, neither of which can appear in a
/// base64 body.
bool isBase64ImagePayload(String s) {
  // Shorter than this is not a usable image either way, so treating it as
  // "no photo" is the safe direction.
  if (s.length <= 100) return false;

  // '.' covers the file extension, '\' the Windows separator, ':' a drive or
  // URI scheme. None are in the base64 alphabet.
  if (s.contains('.') || s.contains(r'\') || s.contains(':')) return false;

  return _base64Body.hasMatch(s);
}
