import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:multicast_dns/multicast_dns.dart';

class EspConnection {
  EspConnection._();
  static final EspConnection I = EspConnection._();

  IOWebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _manuallyClosed = false;

  // Adjust if you changed it in firmware
  final String mdnsHost = 'circadian-light.local';
  final String path = '/ws';
  int port = 80;

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _incoming.stream;
  bool get isConnected => _ch != null;

  Future<void> connect({String? ipOrHost, Duration retry = const Duration(seconds: 2)}) async {
    _manuallyClosed = false;
    final target = ipOrHost ?? await _resolveMdnsHost(mdnsHost);
    if (target == null) {
      _scheduleReconnect(retry);
      return;
    }
    final url = 'ws://$target:$port$path';
    try {
      final socket = await WebSocket.connect(url);
      _ch = IOWebSocketChannel(socket);
      _sub = _ch!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> json = jsonDecode(data as String);
            _incoming.add(json);
          } catch (_) {/* ignore non-JSON */}
        },
        onError: (_) => _handleDisconnect(retry),
        onDone: () => _handleDisconnect(retry),
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect(retry);
    }
  }

  void _handleDisconnect(Duration retry) {
    _sub?.cancel();
    _sub = null;
    _ch = null;
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
      final addrs = await client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(host),
      ).toList();
      if (addrs.isNotEmpty) return addrs.first.address.address;

      // Fallback: discover the _ws._tcp service and read SRV/A
      final services = await client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_ws._tcp.local'),
      ).toList();
      for (final s in services) {
        final srv = await client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(s.domainName),
        ).first;
        final a = await client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        ).first;
        port = srv.port;
        return a.address.address;
      }
      return null;
    } finally {
      client.stop();
    }
  }

  void send(Map<String, dynamic> payload) {
    final c = _ch;
    if (c == null) return;
    c.sink.add(jsonEncode(payload));
  }

  // Convenience helpers for your firmware keys:
  void setA(int value) => send({'a': value.clamp(0, 255)});
  void setB(int value) => send({'b': value.clamp(0, 255)});

  Future<void> close() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _ch?.sink.close(ws_status.normalClosure);
    _ch = null;
  }
}