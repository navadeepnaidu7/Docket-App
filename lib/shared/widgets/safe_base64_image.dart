import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Uint8List? _decodeImagePayload(String payload) {
  try {
    final Uint8List decoded = base64Decode(payload.trim());
    return decoded.isEmpty ? null : decoded;
  } on FormatException {
    return null;
  }
}

/// Renders a base64-encoded image without letting a bad payload take the
/// screen down.
///
/// Every card used to call `base64Decode(...)` straight inside `build`. That
/// throws a `FormatException` on anything that is not valid base64, and a throw
/// inside `build` is not recoverable — the whole wallet renders a red error box
/// rather than one card missing a photo. The ID cards guarded the call with a
/// character-set heuristic, which rules out a filesystem path but not a payload
/// that is merely truncated or corrupt; the passport card had no guard at all.
///
/// Decoding also belongs out of `build`: `build` runs on every scroll frame and
/// re-decoding a DG2 portrait each time is real work. Here it happens once per
/// payload, in [initState] and again only when [base64] actually changes.
/// Large payloads decode in a background isolate on native platforms so mounting
/// a scanned card does not block the scroll or route animation.
///
/// [placeholder] is shown when the payload is empty or will not decode, so a
/// document with no usable photo looks deliberately empty rather than broken.
class SafeBase64Image extends StatefulWidget {
  const SafeBase64Image({
    super.key,
    required this.base64,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String base64;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  State<SafeBase64Image> createState() => _SafeBase64ImageState();
}

class _SafeBase64ImageState extends State<SafeBase64Image> {
  Uint8List? _bytes;
  int _decodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(SafeBase64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) _decode();
  }

  void _decode() {
    final int generation = ++_decodeGeneration;
    final String payload = widget.base64;
    _bytes = null;
    // Avoid isolate setup for small portraits. A 64 KiB base64 string represents
    // about 48 KiB of compressed image data.
    if (payload.length <= 64 * 1024) {
      _bytes = _decodeImagePayload(payload);
      return;
    }
    compute(
      _decodeImagePayload,
      payload,
      debugLabel: 'wallet-portrait-decode',
    ).then((Uint8List? bytes) {
      if (!mounted || generation != _decodeGeneration) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    if (bytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      );
    }
    return Image.memory(
      bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      // Decoding succeeded but the bytes may still not be a known image
      // format, which fails later, inside the codec.
      errorBuilder: (BuildContext context, Object _, StackTrace? _) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      ),
    );
  }
}
