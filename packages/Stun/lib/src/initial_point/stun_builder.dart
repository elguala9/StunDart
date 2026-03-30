import 'dart:io';

import '../implementations/handlers/dual_stun_handler.dart';
import '../implementations/handlers/stun_handler.dart';
import '../implementations/singleton/dual_callback_handler.dart';
import '../interfaces/i_dual_callback_handler.dart';
import '../interfaces/i_dual_stun_handler.dart';

/// Builds and wires an [IDualStunHandler] and [IDualCallbackHandler] from
/// pre-bound sockets. Shared by both the [SingletonDIAccess] and
/// [RegistryAccess] initial-point variants.
({IDualStunHandler dualHandler, IDualCallbackHandler dualCallback})
buildStunHandlers(
  RawDatagramSocket ipv4Socket, {
  RawDatagramSocket? ipv6Socket,
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) {
  final dualHandler = DualStunHandler();
  final dualCallback = DualCallbackHandler();

  dualHandler.setIpv4Handler(
    StunHandler.withSocket(
      ipv4Socket,
      address: address,
      port: port,
      timeout: timeout,
      onSocketRefresh: dualCallback.onIpv4,
    ),
  );

  if (ipv6Socket != null) {
    dualHandler.setIpv6Handler(
      StunHandler.withSocket(
        ipv6Socket,
        address: address,
        port: port,
        timeout: timeout,
        onSocketRefresh: dualCallback.onIpv6,
      ),
    );
  }

  return (dualHandler: dualHandler, dualCallback: dualCallback);
}
