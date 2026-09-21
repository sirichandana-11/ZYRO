import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/validated_location.dart';
import '../services/location_service.dart';

/// Floating development-only GPS & Map Diagnostics Overlay for ZYRO.
class LocationDebugPanel extends StatefulWidget {
  final ValidatedLocation? location;
  final LatLng? mapCenter;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final String? wsStatus;
  final DateTime? driverLocationTime;
  final bool isMapReady;

  const LocationDebugPanel({
    super.key,
    this.location,
    this.mapCenter,
    this.pickupLocation,
    this.destinationLocation,
    this.wsStatus,
    this.driverLocationTime,
    this.isMapReady = true,
  });

  @override
  State<LocationDebugPanel> createState() => _LocationDebugPanelState();
}

class _LocationDebugPanelState extends State<LocationDebugPanel> {
  bool _isExpanded = false;
  final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final loc = widget.location ?? _locationService.lastValidatedLocation;
    final int ageSeconds = loc != null
        ? DateTime.now().difference(loc.timestamp).inSeconds.abs()
        : -1;

    final String driverAge = widget.driverLocationTime != null
        ? '${DateTime.now().difference(widget.driverLocationTime!).inSeconds}s ago'
        : 'N/A';

    return Positioned(
      bottom: 80,
      left: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isExpanded ? 320 : 160,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF475569)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: loc != null
                            ? (loc.isReliable
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B))
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GPS DEBUG',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),

              if (_isExpanded) ...[
                const Divider(height: 10, color: Color(0xFF475569)),
                _buildMetricRow(
                  'GPS Status',
                  loc != null ? (loc.isReliable ? 'LOCKED' : 'ANOMALY') : 'SEARCHING',
                  loc != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                _buildMetricRow(
                  'Latitude',
                  loc != null ? loc.latitude.toStringAsFixed(6) : '---',
                ),
                _buildMetricRow(
                  'Longitude',
                  loc != null ? loc.longitude.toStringAsFixed(6) : '---',
                ),
                _buildMetricRow(
                  'Accuracy',
                  loc != null ? '±${loc.accuracyMeters.toStringAsFixed(1)} m' : '---',
                  (loc?.accuracyMeters ?? 100) < 15
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                _buildMetricRow(
                  'Speed / Head',
                  loc != null
                      ? '${loc.speedMps.toStringAsFixed(1)} m/s | ${loc.headingDegrees.toStringAsFixed(0)}°'
                      : '---',
                ),
                _buildMetricRow(
                  'Sample Age',
                  ageSeconds >= 0 ? '$ageSeconds sec' : '---',
                ),
                _buildMetricRow(
                  'Updates / Rej',
                  '${_locationService.totalUpdatesReceived} / ${_locationService.rejectedJumpsCount}',
                ),
                _buildMetricRow(
                  'Map Center',
                  widget.mapCenter != null
                      ? '${widget.mapCenter!.latitude.toStringAsFixed(4)}, ${widget.mapCenter!.longitude.toStringAsFixed(4)}'
                      : '---',
                ),
                _buildMetricRow(
                  'Pickup GPS',
                  widget.pickupLocation != null
                      ? '${widget.pickupLocation!.latitude.toStringAsFixed(4)}, ${widget.pickupLocation!.longitude.toStringAsFixed(4)}'
                      : '---',
                ),
                _buildMetricRow(
                  'Destination',
                  widget.destinationLocation != null
                      ? '${widget.destinationLocation!.latitude.toStringAsFixed(4)}, ${widget.destinationLocation!.longitude.toStringAsFixed(4)}'
                      : 'None',
                ),
                _buildMetricRow(
                  'WebSocket',
                  widget.wsStatus ?? 'CONNECTED',
                  const Color(0xFF38BDF8),
                ),
                _buildMetricRow(
                  'Driver GPS',
                  driverAge,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ': ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              color: const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
