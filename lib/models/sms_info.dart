class SmsInfo {
  final String date;
  final String address;
  final String body;
  final int timestamp;
  final int type;
  final String contactName;

  SmsInfo({
    required this.date,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.type,
    this.contactName = '',
  });
}
