/// Centralized geographic coordinate validator and utility for ZYRO.
class Coordinate {
  final double latitude;
  final double longitude;

  const Coordinate({
    required this.latitude,
    required this.longitude,
  });

  /// Validates whether a given latitude and longitude pair is numerically and geographically valid.
  static bool isValid(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.isInfinite || lng.isInfinite) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    // Reject empty 0.0, 0.0 null island default unless specifically expected
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  /// Returns true if this coordinate instance is valid.
  bool get isValidCoordinate => Coordinate.isValid(latitude, longitude);

  /// Clamps latitude and longitude to standard GPS ranges.
  static Coordinate clamp(double lat, double lng) {
    final double clampedLat = lat.clamp(-90.0, 90.0);
    final double clampedLng = lng.clamp(-180.0, 180.0);
    return Coordinate(latitude: clampedLat, longitude: clampedLng);
  }

  /// Formats coordinate into human-readable compact string.
  String toDisplayString({int precision = 4}) {
    return '${latitude.toStringAsFixed(precision)}, ${longitude.toStringAsFixed(precision)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinate &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'Coordinate($latitude, $longitude)';
}
