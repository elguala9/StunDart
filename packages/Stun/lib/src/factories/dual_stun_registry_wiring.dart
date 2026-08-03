import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

/// Binds a real IPv4 and a real IPv6 socket and registers each
/// `RawDatagramSocket` under the matching `'ipv4'`/`'ipv6'` subkey.
///
/// `StunHandler`/`StunHandlerMigratable` resolve their socket parameter via
/// `@Subkey.inherited()`, and `MainInjectionStunMixin.registerAllSingletonsStun()`
/// auto-connects both of them once per subkey demanded elsewhere in the
/// graph (`DualStunHandler`/`DualStunHandlerMigratable`'s own
/// `@Subkey('ipv4')`/`@Subkey('ipv6')` params) — but `RawDatagramSocket`
/// itself is a plain `dart:io` class, not `@dependencyInjectable`, so nothing
/// ever supplies it. Without this, resolving `IDualStunHandler`/
/// `IDualStunHandlerMigratable` throws `RegistryNotFoundError` for
/// `RawDatagramSocket` as soon as the generated factory tries to build the
/// `ipv4`/`ipv6` handler.
///
/// Call this once per [key] before resolving `IDualStunHandler`/
/// `IDualStunHandlerMigratable` under that same [key] — order relative to
/// `registerAllSingletonsStun()` doesn't matter, since `RawDatagramSocket` and
/// `IStunHandler`/`IStunHandlerMigratable` are different registry slots.
///
/// DI-resolved handlers always use the STUN config defaults for the server
/// address/port (call `setStunServer` on the resolved handler afterwards for
/// a custom one) — construct a `StunHandler`/`StunHandlerMigratable` directly
/// instead of going through the registry if the server needs to be known at
/// construction time.
///
/// `StunHandler` and `StunHandlerMigratable` both resolve a `RawDatagramSocket`
/// under the same (key, subkey), so if both are ever built under the same
/// [key] they end up sharing the same socket — expected, since they'd be
/// two independent representations of "the same" ipv4/ipv6 endpoint; don't
/// build both under the same key at once if that's not what you want.
Future<void> connectDualStunHandlerSockets({String key = 'default'}) async {
  final ipv4Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final ipv6Socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);

  RegistryManager.instance
    ..connectInstance<RawDatagramSocket, RawDatagramSocket>(
      () => ipv4Socket,
      key: key,
      subkey: 'ipv4',
    )
    ..connectInstance<RawDatagramSocket, RawDatagramSocket>(
      () => ipv6Socket,
      key: key,
      subkey: 'ipv6',
    );
}
