import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../types/stun_types.dart';

/// Binds a real IPv4 and a real IPv6 socket and registers a `StunHandlerInput`
/// under the matching `'ipv4'`/`'ipv6'` subkey.
///
/// `StunHandler`/`StunHandlerMigratable` resolve their `input` parameter via
/// `@Subkey.inherited()`, and `MainInjectionStunMixin.registerAllSingletonsStun()`
/// auto-connects both of them once per subkey demanded elsewhere in the
/// graph (`DualStunHandler`/`DualStunHandlerMigratable`'s own
/// `@Subkey('ipv4')`/`@Subkey('ipv6')` params) — but `StunHandlerInput`
/// itself is a plain class, not `@dependencyInjectable`, so nothing ever
/// supplies it. Without this, resolving `IDualStunHandler`/
/// `IDualStunHandlerMigratable` throws `RegistryNotFoundError` for
/// `StunHandlerInput` as soon as the generated factory tries to build the
/// `ipv4`/`ipv6` handler.
///
/// Call this once per [key] before resolving `IDualStunHandler`/
/// `IDualStunHandlerMigratable` under that same [key] — order relative to
/// `registerAllSingletonsStun()` doesn't matter, since `StunHandlerInput` and
/// `IStunHandler`/`IStunHandlerMigratable` are different registry slots.
///
/// `StunHandler` and `StunHandlerMigratable` both resolve `StunHandlerInput`
/// under the same (key, subkey), so if both are ever built under the same
/// [key] they end up sharing the same socket — expected, since they'd be
/// two independent representations of "the same" ipv4/ipv6 endpoint; don't
/// build both under the same key at once if that's not what you want.
Future<void> connectDualStunHandlerSockets({
  String key = 'default',
  String? address,
  int? port,
}) async {
  final ipv4Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final ipv6Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);

  RegistryManager.instance
    ..connectInstance<StunHandlerInput, StunHandlerInput>(
      () => StunHandlerInput(address: address, port: port, socket: ipv4Socket),
      key: key,
      subkey: 'ipv4',
    )
    ..connectInstance<StunHandlerInput, StunHandlerInput>(
      () => StunHandlerInput(address: address, port: port, socket: ipv6Socket),
      key: key,
      subkey: 'ipv6',
    );
}
