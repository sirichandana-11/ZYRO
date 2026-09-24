import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/coordinate.dart';

/// Connection states for the ZYRO WebSocket service.
enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  authenticated,
  error,
}

/// Strongly typed driver location event from WebSocket.
class DriverLocationEvent {
  final String driverId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final double? heading;
  final String? rideId;

  const DriverLocationEvent({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    this.heading,
    this.rideId,
  });

  factory DriverLocationEvent.fromJson(Map<String, dynamic> json) {
    return DriverLocationEvent(
      driverId: json['driverId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 10.0,
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      rideId: json['rideId'] as String?,
    );
  }
}

/// Strongly typed incoming ride request event for drivers.
class RideRequestEvent {
  final String rideId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String rideType;
  final double fare;
  final DateTime? expiresAt;

  const RideRequestEvent({
    required this.rideId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.rideType,
    required this.fare,
    this.expiresAt,
  });

  factory RideRequestEvent.fromJson(Map<String, dynamic> json) {
    final expRaw = json['expiresAt'];
    DateTime? exp;
    if (expRaw is int) {
      exp = DateTime.fromMillisecondsSinceEpoch(expRaw);
    } else if (expRaw is String) {
      exp = DateTime.tryParse(expRaw);
    }

    return RideRequestEvent(
      rideId: json['rideId'] as String? ?? '',
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble() ?? 0.0,
      destinationLatitude: (json['destinationLatitude'] as num?)?.toDouble() ?? 0.0,
      destinationLongitude: (json['destinationLongitude'] as num?)?.toDouble() ?? 0.0,
      rideType: json['rideType'] as String? ?? 'bike',
      fare: (json['fare'] as num?)?.toDouble() ?? 49.0,
      expiresAt: exp,
    );
  }
}

/// Strongly typed ride assignment notification.
class RideAssignedEvent {
  final String rideId;
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final String? vehicleNumber;
  final String? vehicleType;
  final double latitude;
  final double longitude;

  const RideAssignedEvent({
    required this.rideId,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.vehicleNumber,
    this.vehicleType,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory RideAssignedEvent.fromJson(Map<String, dynamic> json) {
    return RideAssignedEvent(
      rideId: json['rideId'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      driverName: json['driverName'] as String? ?? 'Assigned Driver',
      driverPhone: json['driverPhone'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      vehicleType: json['vehicleType'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Client configuration for WebSocket URL resolution across Web, Emulators, and Physical Devices.
class WebSocketConfig {
  static String? customServerUrl;

  static String get defaultUrl {
    if (customServerUrl != null && customServerUrl!.isNotEmpty) {
      return customServerUrl!;
    }

    if (kIsWeb) {
      return 'ws://localhost:8085';
    }

    try {
      if (Platform.isAndroid) {
        // 10.0.2.2 is Android emulator host loopback.
        // For physical device on same WiFi, set WebSocketConfig.customServerUrl = 'ws://<DEV_PC_IP>:8085'.
        return 'ws://10.0.2.2:8085';
      } else if (Platform.isIOS) {
        return 'ws://localhost:8085';
      }
    } catch (_) {}

    return 'ws://localhost:8085';
  }
}

/// Centralized WebSocket client service for ZYRO.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  static WebSocketService get instance => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  WebSocketConnectionStatus _status = WebSocketConnectionStatus.disconnected;
  WebSocketConnectionStatus get status => _status;
  bool get isConnected => _status == WebSocketConnectionStatus.connected || _status == WebSocketConnectionStatus.authenticated;
  bool get isAuthenticated => _status == WebSocketConnectionStatus.authenticated;

  int _reconnectAttempts = 0;
  bool _isDisposed = false;
  String? _authenticatedUid;
  String? _authenticatedRole;

  // Broadcast controllers for typed event streams
  final _statusController = StreamController<WebSocketConnectionStatus>.broadcast();
  final _rawEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController = StreamController<DriverLocationEvent>.broadcast();
  final _rideRequestController = StreamController<RideRequestEvent>.broadcast();
  final _rideAssignedController = StreamController<RideAssignedEvent>.broadcast();
  final _rideStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideCancelledController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<WebSocketConnectionStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get rawEventStream => _rawEventController.stream;
  Stream<DriverLocationEvent> get onDriverLocation => _driverLocationController.stream;
  Stream<RideRequestEvent> get onRideRequest => _rideRequestController.stream;
  Stream<RideAssignedEvent> get onRideAssigned => _rideAssignedController.stream;
  Stream<Map<String, dynamic>> get onRideStatusChanged => _rideStatusController.stream;
  Stream<Map<String, dynamic>> get onRideCancelled => _rideCancelledController.stream;

  final Set<String> _activeSubscribedRides = {};

  /// Connects and authenticates with the ZYRO WebSocket server.
  Future<void> connect({String? serverUrl}) async {
    if (_isDisposed) return;
    if (_status == WebSocketConnectionStatus.connecting || _status == WebSocketConnectionStatus.authenticated) {
      return;
    }

    _setStatus(WebSocketConnectionStatus.connecting);
    final url = serverUrl ?? WebSocketConfig.defaultUrl;

    try {
      debugPrint('[WS] Connecting to $url...');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Await ready
      await _channel!.ready;
      _setStatus(WebSocketConnectionStatus.connected);
      _reconnectAttempts = 0;
      debugPrint('[WS] Connected successfully.');

      _startHeartbeat();

      _channelSubscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (err) {
          debugPrint('[WS] Stream error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WS] Stream closed by server.');
          _handleDisconnect();
        },
      );

      // Authenticate immediately after connection
      await authenticate();
    } catch (e) {
      debugPrint('[WS] Connection failed: $e');
      _handleDisconnect();
    }
  }

  /// Sends Firebase Auth ID token to authenticate the WebSocket connection.
  Future<void> authenticate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? token;

      if (user != null) {
        token = await user.getIdToken();
      } else {
        // Local dev mock token fallback when running without logged-in user
        token = 'mock_token_rider_local:rider';
      }

      if (token != null) {
        sendMessage('authenticate', {'token': token});
      }
    } catch (e) {
      debugPrint('[WS] Error retrieving auth token: $e');
    }
  }

  /// Sends a structured JSON message over WebSocket.
  bool sendMessage(String type, Map<String, dynamic> payload) {
    if (_channel == null || _status == WebSocketConnectionStatus.disconnected) {
      return false;
    }

    try {
      final message = {
        'type': type,
        'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
      };

      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('[WS] Error sending message: $e');
      return false;
    }
  }

  /// Emits driver online status.
  void sendDriverOnline({
    String? driverId,
    double? latitude,
    double? longitude,
    String vehicleType = 'bike',
  }) {
    final payload = <String, dynamic>{
      'vehicleType': vehicleType,
    };
    if (driverId != null) payload['driverId'] = driverId;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;

    sendMessage('driver_online', payload);
  }

  /// Emits driver offline status.
  void sendDriverOffline({String? driverId}) {
    final payload = <String, dynamic>{};
    if (driverId != null) payload['driverId'] = driverId;

    sendMessage('driver_offline', payload);
  }

  /// Emits high-speed live driver GPS telemetry.
  void sendDriverLocation({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    double? speed,
    double? heading,
    String? rideId,
    String? activeRideId,
  }) {
    if (!Coordinate.isValid(latitude, longitude)) return;

    final targetRideId = rideId ?? activeRideId;
    final payload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    };
    if (speed != null) payload['speed'] = speed;
    if (heading != null) payload['heading'] = heading;
    if (targetRideId != null) payload['rideId'] = targetRideId;

    sendMessage('driver_location', payload);
  }

  /// Emits ride assigned notification over WebSocket.
  void sendRideAssigned({
    required String rideId,
    required String driverId,
    required String driverName,
    String? driverPhone,
    String? vehicleNumber,
    String? vehicleType,
    double? latitude,
    double? longitude,
  }) {
    final payload = <String, dynamic>{
      'rideId': rideId,
      'driverId': driverId,
      'driverName': driverName,
    };
    if (driverPhone != null) payload['driverPhone'] = driverPhone;
    if (vehicleNumber != null) payload['vehicleNumber'] = vehicleNumber;
    if (vehicleType != null) payload['vehicleType'] = vehicleType;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;

    sendMessage('ride_assigned', payload);
  }

  /// Emits ride cancelled notification over WebSocket.
  void sendRideCancelled({
    required String rideId,
    String? reason,
  }) {
    final payload = <String, dynamic>{
      'rideId': rideId,
    };
    if (reason != null) payload['reason'] = reason;

    sendMessage('ride_cancelled', payload);
  }

  /// Subscribes to real-time events for a specific ride.
  void subscribeRide(String rideId) {
    if (rideId.isEmpty) return;
    _activeSubscribedRides.add(rideId);
    sendMessage('subscribe_ride', {'rideId': rideId});
  }

  /// Unsubscribes from a ride.
  void unsubscribeRide(String rideId) {
    if (rideId.isEmpty) return;
    _activeSubscribedRides.remove(rideId);
    sendMessage('unsubscribe_ride', {'rideId': rideId});
  }

  void _handleIncomingMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      _rawEventController.add(data);

      switch (type) {
        case 'authenticated':
          _authenticatedUid = payload['uid'] as String?;
          _authenticatedRole = payload['role'] as String?;
          _setStatus(WebSocketConnectionStatus.authenticated);
          debugPrint('[WS] Authenticated as $_authenticatedRole (UID: $_authenticatedUid)');

          // Re-subscribe active rides after reconnect
          for (final rideId in _activeSubscribedRides) {
            sendMessage('subscribe_ride', {'rideId': rideId});
          }
          break;

        case 'authentication_error':
          debugPrint('[WS] Auth error: ${payload['message']}');
          _setStatus(WebSocketConnectionStatus.error);
          break;

        case 'driver_location':
          final event = DriverLocationEvent.fromJson(payload);
          if (Coordinate.isValid(event.latitude, event.longitude)) {
            _driverLocationController.add(event);
          }
          break;

        case 'ride_request':
          _rideRequestController.add(RideRequestEvent.fromJson(payload));
          break;

        case 'ride_assigned':
          _rideAssignedController.add(RideAssignedEvent.fromJson(payload));
          break;

        case 'ride_cancelled':
          _rideCancelledController.add(payload);
          break;

        case 'ride_status_changed':
          _rideStatusController.add(payload);
          break;

        case 'pong':
          // Heartbeat ack
          break;

        case 'error':
          debugPrint('[WS] Server error: ${payload['message']}');
          break;
      }
    } catch (e) {
      debugPrint('[WS] Message parse error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) {
        sendMessage('ping', {});
      }
    });
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_status != WebSocketConnectionStatus.disconnected) {
      _setStatus(WebSocketConnectionStatus.disconnected);
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 30);
    _reconnectAttempts++;

    debugPrint('[WS] Reconnecting in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void _setStatus(WebSocketConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Cleanly closes the WebSocket connection.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channelSubscription?.cancel();

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }

    _setStatus(WebSocketConnectionStatus.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _statusController.close();
    _rawEventController.close();
    _driverLocationController.close();
    _rideRequestController.close();
    _rideAssignedController.close();
    _rideStatusController.close();
  }
}
