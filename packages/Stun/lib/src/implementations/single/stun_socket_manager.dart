import 'dart:io';
import '../../mixins/single/stun_logger_mixin.dart';
import '../../types/stun_types.dart';

/// Manages socket lifecycle, caching, and local IP resolution
class StunSocketManager with StunLoggerMixin {
  StunSocketManager({required this.socket, required this.onLog})
      : bindType = socket.address.type;

  /// Family the current (and any recreated) socket binds to.
  final InternetAddressType bindType;

  @override
  final void Function(String)? onLog;

  RawDatagramSocket socket;
  StunResponse? cachedStunResponse;
  LocalInfo? cachedLocalInfo;
  DateTime? lastStunUpdated;
  DateTime? lastLocalUpdated;

  /// Binds a fresh socket for [bindType], logging via [onLog] when given.
  static Future<RawDatagramSocket> bindSocket({
    required InternetAddressType bindType,
    void Function(String)? onLog,
  }) async {
    final bindAddr = bindType == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;

    final socket = await RawDatagramSocket.bind(
      bindAddr,
      0,
      reuseAddress: true,
    );
    onLog?.call('[StunHandler] Socket created: ${socket.address}:${socket.port}');
    return socket;
  }

  // Socket operations
  Future<void> recreateSocket() async {
    resetCache();
    socket.close();
    socket = await bindSocket(bindType: bindType, onLog: onLog);
    log('[StunHandler] Socket recreated with new port');
  }

  void closeSocket() => socket.close();

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
    cachedStunResponse = null;
    cachedLocalInfo = null;
    lastStunUpdated = null;
    lastLocalUpdated = null;
  }
}
