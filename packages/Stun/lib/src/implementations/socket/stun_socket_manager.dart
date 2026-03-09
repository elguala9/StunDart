import 'dart:io';
import '../../types/stun_types.dart';

/// Manages socket lifecycle, caching, and local IP resolution
class StunSocketManager {
  final InternetAddressType bindType;
  final int? bindPort;
  final void Function(String)? onLog;

  RawDatagramSocket? _socket;
  StunResponse? _cachedStunResponse;
  LocalInfo? _cachedLocalInfo;
  DateTime? _lastStunUpdated;
  DateTime? _lastLocalUpdated;

  StunSocketManager({
    required this.bindType,
    required this.bindPort,
    required this.onLog,
  });

  void _log(String message) => onLog?.call(message);

  // Socket operations
  Future<RawDatagramSocket> getSocket() async {
    if (_socket != null) return _socket!;

    final bindAddr = bindType == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;

    _socket = await RawDatagramSocket.bind(bindAddr, bindPort ?? 0, reuseAddress: true);
    _log('[StunHandler] Socket created: ${_socket!.address}:${_socket!.port}');
    return _socket!;
  }

  Future<void> recreateSocket() async {
    resetCache();
    _socket?.close();
    _socket = null;
    await getSocket();
    _log('[StunHandler] Socket recreated with new port');
  }

  void closeSocket() => _socket?.close();

  Future<String> getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: bindType,
    );

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }

    return bindType == InternetAddressType.IPv6
        ? InternetAddress.loopbackIPv6.address
        : InternetAddress.loopbackIPv4.address;
  }

  // Cache operations
  void resetCache() {
    _cachedStunResponse = null;
    _cachedLocalInfo = null;
    _lastStunUpdated = null;
    _lastLocalUpdated = null;
  }

  // Getters and setters
  RawDatagramSocket? get socket => _socket;
  set socket(RawDatagramSocket? value) => _socket = value;
  StunResponse? get cachedStunResponse => _cachedStunResponse;
  set cachedStunResponse(StunResponse? value) => _cachedStunResponse = value;

  LocalInfo? get cachedLocalInfo => _cachedLocalInfo;
  set cachedLocalInfo(LocalInfo? value) => _cachedLocalInfo = value;

  DateTime? get lastStunUpdated => _lastStunUpdated;
  set lastStunUpdated(DateTime? value) => _lastStunUpdated = value;

  DateTime? get lastLocalUpdated => _lastLocalUpdated;
  set lastLocalUpdated(DateTime? value) => _lastLocalUpdated = value;
}
