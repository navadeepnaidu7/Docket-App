import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/ids/domain/id_document.dart';
import '../../features/passport/domain/passport_profile.dart';

class DecodedRecords<T> {
  const DecodedRecords(
    this.records, {
    this.needsMigration = false,
    this.hasInvalidRecords = false,
  });

  final List<T> records;
  final bool needsMigration;
  final bool hasInvalidRecords;
}

/// Small wallets avoid isolate startup; large records (including chip photos)
/// are decoded off the UI isolate. The callback must not capture a Ref/widget.
Future<DecodedRecords<T>> decodeStoredRecords<T>(
  List<String> sources,
  ComputeCallback<List<String>, DecodedRecords<T>> decoder,
) {
  final characters = sources.fold<int>(0, (sum, source) => sum + source.length);
  if (sources.length >= 64 || characters >= 64 * 1024) {
    return compute(decoder, sources, debugLabel: 'decode wallet records');
  }
  return Future.value(decoder(sources));
}

DecodedRecords<PassportProfile> decodePassportRecords(List<String> sources) {
  final records = <PassportProfile>[];
  var migrated = false;
  var invalid = false;
  for (final source in sources) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final profile = PassportProfile.fromMap(map);
      migrated |= PassportProfile.mapNeedsMigration(map);
      records.add(profile);
    } catch (_) {
      invalid = true;
    }
  }
  return DecodedRecords(
    records,
    needsMigration: migrated,
    hasInvalidRecords: invalid,
  );
}

DecodedRecords<IdDocument> decodeIdRecords(List<String> sources) {
  final records = <IdDocument>[];
  var invalid = false;
  for (final source in sources) {
    try {
      records.add(IdDocument.fromJson(source));
    } catch (_) {
      invalid = true;
    }
  }
  return DecodedRecords(records, hasInvalidRecords: invalid);
}
