class DeviceRegistration {
  const DeviceRegistration(this.account, this.token, this.timezone, this.at);
  final String account, token, timezone;
  final DateTime at;
  bool isStale(String account, String token, String timezone, DateTime now) =>
      this.account != account ||
      this.token != token ||
      this.timezone != timezone ||
      now.difference(at) >= const Duration(days: 7) ||
      now.isBefore(at);
  Map<String, dynamic> toJson() => {
    'account': account,
    'token': token,
    'timezone': timezone,
    'at': at.toUtc().toIso8601String(),
  };
  static DeviceRegistration? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse('${json['at']}');
    return at == null
        ? null
        : DeviceRegistration(
            '${json['account']}',
            '${json['token']}',
            '${json['timezone']}',
            at,
          );
  }
}
