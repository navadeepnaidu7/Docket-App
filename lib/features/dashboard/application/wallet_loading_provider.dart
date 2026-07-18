import 'package:flutter_riverpod/flutter_riverpod.dart';

final passportLoadingProvider = StateProvider<bool>((ref) => true);
final idLoadingProvider = StateProvider<bool>((ref) => true);

final walletLoadingProvider = Provider<bool>((ref) {
  final passportLoading = ref.watch(passportLoadingProvider);
  final idLoading = ref.watch(idLoadingProvider);
  return passportLoading || idLoading;
});
