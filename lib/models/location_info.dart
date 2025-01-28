class LocationInfo {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  String address;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    this.address = 'Fetching address...',
  });

  factory LocationInfo.fromFirebase(String timestampKey, Map<dynamic, dynamic> data) {
    return LocationInfo(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      accuracy: (data['accuracy'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(timestampKey)),
    );
  }
}
