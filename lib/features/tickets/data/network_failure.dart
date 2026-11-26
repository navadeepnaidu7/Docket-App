import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/pass_ingest.dart';

/// True when [error] means the server was unreachable, not that it refused.
///
/// Only these failures keep the saved wallet on screen or queue an addition.
bool isNetworkFailure(Object error) =>
    error is SocketException ||
    error is HandshakeException ||
    error is http.ClientException ||
    error is TimeoutException ||
    // DocketApiClient maps its request timeout to this message.
    (error is PassIngestException &&
        error.code == PassIngestCode.failed &&
        error.message.contains('timed out'));
