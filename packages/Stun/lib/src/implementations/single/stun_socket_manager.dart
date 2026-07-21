import 'dart:io';
import '../../mixins/single/stun_logger_mixin.dart';
import '../../types/stun_types.dart';

/// Manages socket lifecycle, caching, and local IP resolution
class StunSocketManager with StunLoggerMixin {
  StunSocketManager({
    required this.bindType,
    required this.bindPort,
    required this.onLog,
  });

  final InternetAddressType bindType;
  final int? bindPort;

  @override
  final void Function(String)? onLog;

  RawDatagramSocket? socket;
  StunResponse? cachedStunResponse;
  LocalInfo? cachedLocalInfo;
  DateTime? lastStunUpdated;
  DateTime? lastLocalUpdated;

  // Socket operations
  Future<RawDatagramSocket> getSocket() async {
    if (socket != null) return socket!;

    final bindAddr = bindType == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;

    socket = await RawDatagramSocket.bind(
      bindAddr,
      bindPort ?? 0,
      reuseAddress: true,
    );
    log('[StunHandler] Socket created: ${socket!.address}:${socket!.port}');
    return socket!;
  }

  Future<void> recreateSocket() async {
    resetCache();
    socket?.close();
    socket = null;
    await getSocket();
    log('[StunHandler] Socket recreated with new port');
  }

  void closeSocket() => socket?.close();

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
