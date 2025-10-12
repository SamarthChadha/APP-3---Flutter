// Manages WebSocket connection to ESP32 device for real-time control
// and state synchronization

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:multicast_dns/multicast_dns.dart';

// Data class representing the current state of the ESP32 lamp
class EspState {
  final int brightness; // 0-15
  final int mode; // 0=warm, 1=white, 2=both
  final bool isOn;

  const EspState({
    required this.brightness,
    required this.mode,
    required this.isOn,
  });

  // Create EspState from JSON received from ESP32
  factory EspState.fromJson(Map<String, dynamic> json) {
    return EspState(
      brightness: json['brightness'] ?? 0,
      mode: json['mode'] ?? 2,
      isOn: json['on'] ?? true,
    );
  }

  // Convert ESP brightness (1-15) to Flutter UI brightness (0.0-1.0)
  double get flutterBrightness {
    // Map ESP brightness 1-15 to Flutter 0.0-1.0
    // Ensure brightness of 1 maps to 0.0 for UI slider
    if (brightness <= 1) return 0.0;
    return (brightness - 1) / 14.0; // Map 1-15 to 0.0-1.0
  }

  // Convert ESP mode to approximate color temperature in Kelvin
  double get flutterTemperature {
    // Map ESP32 modes to temperature values
    switch (mode) {
      case 0:
        return 2700; // warm
      case 1:
        return 6500; // white
      case 2:
        return 4600; // both (exactly in the middle: (2700 + 6500) / 2)
      default:
        return 4600;
    }
  }
}

// Singleton class managing WebSocket connection to ESP32
class EspConnection {
  EspConnection._();
  static final EspConnection I = EspConnection._();

  IOWebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _manuallyClosed = false;
  bool _connecting = false;

  // Adjust if you changed it in firmware
  final String mdnsHost = 'circadian-light.local';
  final String path = '/ws';
  int port = 80;

  // Stream of incoming messages from ESP32
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _incoming.stream;
  bool get isConnected => _ch != null;

  // Connection status stream: true when connected, false on disconnect
  final _connection = StreamController<bool>.broadcast();
  Stream<bool> get connection => _connection.stream;

  // State update stream: emits when ESP32 sends state updates
  final _stateUpdates = StreamController<EspState>.broadcast();
  Stream<EspState> get stateUpdates => _stateUpdates.stream;

  // Connect to ESP32 via WebSocket, with automatic mDNS resolution
  // and reconnection
  Future<void> connect({
    String? ipOrHost,
    Duration retry = const Duration(seconds: 2),
  }) async {
    if (_connecting || _ch != null) return;
    _connecting = true;
    _manuallyClosed = false;

    String? target;
    try {
      if (ipOrHost != null) {
        target = ipOrHost;
      } else if (Platform.isIOS) {
        // On iOS, rely on system Bonjour for .local hostnames
        // to avoid multicast join errors
        target = mdnsHost;
      } else {
        target = await _resolveMdnsHost(mdnsHost);
      }
    } catch (_) {
      // Fallback: try the mDNS hostname directly; if that fails,
      // we'll reconnect later
      target = mdnsHost;
    }

    if (target == null) {
      _connecting = false;
      _connection.add(false);
      _scheduleReconnect(retry);
      return;
    }

    final url = 'ws://$target:$port$path';
    try {
      final socket = await WebSocket.connect(url);
      _ch = IOWebSocketChannel(socket);
      _connection.add(true);

      _sub = _ch!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> json = jsonDecode(data as String);
            _incoming.add(json);

            // Check if this is a state update from ESP32
            if (json.containsKey('state')) {
              final state = EspState.fromJson(json['state']);
              _stateUpdates.add(state);
            }
          } catch (_) {
            /* ignore non-JSON */
          }
        },
        onError: (_) => _handleDisconnect(retry),
        onDone: () => _handleDisconnect(retry),
        cancelOnError: true,
      );

      // Request current state from ESP after successful connection
      Timer(const Duration(milliseconds: 500), () {
        requestCurrentState();
      });
    } catch (_) {
      _handleDisconnect(retry);
    } finally {
      _connecting = false;
    }
  }

  // Handle disconnection and schedule reconnection if not manually closed
  void _handleDisconnect(Duration retry) {
    _sub?.cancel();
    _sub = null;
    _ch = null;
    // Notify disconnected
    _connection.add(false);
    if (!_manuallyClosed) _scheduleReconnect(retry);
  }

  void _scheduleReconnect(Duration retry) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(retry, () => connect());
  }

  Future<String?> _resolveMdnsHost(String host) async {
    final client = MDnsClient();
    try {
      await client.start();
      // Prefer direct A lookup for circadian-light.local
      final addrs = await client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(host),
          )
          .toList();
      if (addrs.isNotEmpty) return addrs.first.address.address;

      // Fallback: discover the _ws._tcp service and read SRV/A
      final services = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_ws._tcp.local'),
          )
          .toList();
      for (final s in services) {
        final srv = await client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(s.domainName),
            )
            .first;
        final a = await client
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )
            .first;
        port = srv.port;
        return a.address.address;
      }
      return null;
    } catch (_) {
      // Any mDNS issue should not crash the app; return null
      // so caller can fallback
      return null;
    } finally {
      try {
        client.stop();
      } catch (_) {}
    }
  }

  // Send JSON message to ESP32
  void send(Map<String, dynamic> payload) {
    final c = _ch;
    if (c == null) return;
    c.sink.add(jsonEncode(payload));
  }

  // Convenience helpers for your firmware keys:
  void setA(int value) => send({'a': value.clamp(0, 255)});
  void setB(int value) => send({'b': value.clamp(0, 255)});

  // Firmware JSON protocol (see ESP32 main):
  // { "brightness": 0..15, "mode": 0..2, "on": true/false }
  void setBrightness(int value) =>
      send({'brightness': value.clamp(1, 15)}); // Min 1 instead of 0
  void setMode(int value) => send({'mode': value.clamp(0, 2)});
  void setOn(bool on) => send({'on': on});

  // Request current state from ESP32
  void requestCurrentState() => send({'request_state': true});

  // Close WebSocket connection and clean up resources
  Future<void> close() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _ch?.sink.close(ws_status.normalClosure);
    _ch = null;
    _connection.add(false);
    await _stateUpdates.close();
  }
}
