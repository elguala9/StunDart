import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../implementations/singleton/dual_stun_handler_base.dart';
import '../interfaces/i_dual_callback_handler.dart';
import '../interfaces/i_dual_stun_handler.dart';
import '../interfaces/i_stun_handler_base.dart';
import 'stun_builder.dart';

/// Registry-aware subclass of [DualStunHandlerBase] that accepts its dependencies
/// directly instead of reading them from [SingletonDIAccess].
/// Registered under a string [key] via [RegistryAccess] as [IStunHandlerBase].
class _DualStunHandlerBaseEntry extends DualStunHandlerBase {
  _DualStunHandlerBaseEntry(IDualStunHandler handler, IDualCallbackHandler cb) {
    dualHandlerProtected = handler;
    callbacks = cb;
  }
}

/// Initializes all STUN components from pre-bound sockets and registers them
/// in the global registry under [key] as [IStunHandlerBase].
///
/// Retrieve the result with:
/// ```dart
/// final stun = RegistryAccess.getInstance<IStunHandlerBase>(key);
/// ```
Future<void> initialPointStunWithSocketsRegistry(
  String key,
  RawDatagramSocket ipv4Socket, {
  RawDatagramSocket? ipv6Socket,
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final (:dualHandler, :dualCallback) = buildStunHandlers(
    ipv4Socket,
    ipv6Socket: ipv6Socket,
    address: address,
    port: port,
    timeout: timeout,
  );

  if (RegistryAccess.contains<IStunHandlerBase>(key)) {
    RegistryAccess.unregister<IStunHandlerBase>(key);
  }
  RegistryAccess.register<IStunHandlerBase>(
    key,
    _DualStunHandlerBaseEntry(dualHandler, dualCallback),
  );
}

/// Binds IPv4 and IPv6 sockets, then initializes all STUN components and
/// registers them in the global registry under [key] as [IStunHandlerBase].
///
/// Retrieve the result with:
/// ```dart
/// final stun = RegistryAccess.getInstance<IStunHandlerBase>(key);
/// ```
Future<void> initialPointStunRegistry(
  String key, {
  String? address,
  int? port,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final ipv4Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  RawDatagramSocket? ipv6Socket;
  try {
    ipv6Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
  } catch (_) {}

  await initialPointStunWithSocketsRegistry(
    key,
    ipv4Socket,
    ipv6Socket: ipv6Socket,
    address: address,
    port: port,
    timeout: timeout,
  );
}
