import 'dart:io';

import '../implementations/dual/dual_stun_handler.dart';
import '../implementations/single/stun_handler.dart';
import '../interfaces/dual/i_dual_stun_handler.dart';

/// Builds and wires an [IDualStunHandler] from pre-bound sockets.
/// Shared by both the [SingletonDIAccess] and [RegistryAccess] initial-point
/// variants.
IDualStunHandler buildStunHandlers(
  RawDatagramSocket ipv4Socket, {
  RawDatagramSocket? ipv6Socket,
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) {
  final dualHandler = DualStunHandler();

  dualHandler.setHandler(
    StunHandler.withSocket(
      ipv4Socket,
      address: address,
      port: port,
      timeout: timeout,
    ),
    type: InternetAddressType.IPv4,
  );

  if (ipv6Socket != null) {
    dualHandler.setHandler(
      StunHandler.withSocket(
        ipv6Socket,
        address: address,
        port: port,
        timeout: timeout,
      ),
      type: InternetAddressType.IPv6,
    );
  }

  return dualHandler;
}
