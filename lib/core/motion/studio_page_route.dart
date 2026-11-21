import 'package:flutter/material.dart';

/// Peer destinations share the platform transition policy in AppTheme with
/// ordinary routes. Sheets and media overlays keep their own presentation.
Route<T> studioPageRoute<T>({required WidgetBuilder builder}) =>
    MaterialPageRoute<T>(builder: builder);
