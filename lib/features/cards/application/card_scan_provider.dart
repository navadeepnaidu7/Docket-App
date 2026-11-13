import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/card_scan_store.dart';

final cardScanStoreProvider = Provider<CardScanStore>((ref) => CardScanStore());
