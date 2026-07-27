import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import '../generated/dual_stun_handler_base_di.dart';
import '../interfaces/dual/i_dual_stun_handler.dart';

import 'stun_builder.dart';

/// Initializes all STUN components from pre-bound sockets and registers them in the DI container.
Future<void> initialPointStunWithSockets(
  RawDatagramSocket ipv4Socket, {
  RawDatagramSocket? ipv6Socket,
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final dualHandler = buildStunHandlers(
    ipv4Socket,
    ipv6Socket: ipv6Socket,
    address: address,
    port: port,
    timeout: timeout,
  );

  SingletonDIAccess.addInstanceAs<IDualStunHandler, IDualStunHandler>(
    dualHandler,
  );
  SingletonDIAccess.addInstance(DualStunHandlerBaseDI.initializeDI());
}

/// Binds IPv4 and IPv6 sockets, then initializes all STUN components in the DI container.
Future<void> initialPointStun({
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final ipv4Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  RawDatagramSocket? ipv6Socket;
  try {
    ipv6Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
  } catch (_) {}

  await initialPointStunWithSockets(
    ipv4Socket,
    ipv6Socket: ipv6Socket,
    address: address,
    port: port,
    timeout: timeout,
  );
}
