enum CallType { missed, incoming, outgoing, unknown }

class CallInfo {
  final String name;
  final String phoneNumber;
  final DateTime timestamp;
  final CallType type;
  final Duration? duration;
  final String contactName;

  CallInfo({
    required this.name,
    required this.phoneNumber,
    required this.timestamp,
    required this.type,
    this.duration,
    this.contactName = '',
  });
}
