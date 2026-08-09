import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../interfaces/dual/i_dual_stun_handler_migratable.dart';
import '../interfaces/single/i_stun_handler.dart';
import 'stun_handler_socket_migration.dart';

/// Migrates the ipv4 and/or ipv6 plain `IStunHandler` slots for the
/// [IDualStunHandlerMigratable] registered under [key] in one call, instead
/// of calling [migrateStunHandlerSocket] once per family by hand.
///
/// Pass whichever of [ipv4Socket]/[ipv6Socket] needs migrating — the other
/// can be left `null` to leave that family untouched. Each socket must
/// actually be of the family it's passed as (an `IPv6` [ipv4Socket] throws
/// [ArgumentError]), since [migrateStunHandlerSocket] otherwise infers the
/// subkey from the socket itself and a mismatch would silently migrate the
/// wrong slot.
///
/// As with [migrateStunHandlerSocket], the dual handler's own ipv4/ipv6
/// slots — the registered [IStunHandlerMigratable] instances — are never
/// replaced; only the plain `IStunHandler`/`RawDatagramSocket` entries move.
({IStunHandler? ipv4, IStunHandler? ipv6}) migrateDualStunHandlerSockets({
  RawDatagramSocket? ipv4Socket,
  RawDatagramSocket? ipv6Socket,
  String key = 'default',
}) {
  if (ipv4Socket == null && ipv6Socket == null) {
    throw ArgumentError(
      'migrateDualStunHandlerSockets: pass at least one of '
      'ipv4Socket/ipv6Socket.',
    );
  }

  // Fetching the dual handler confirms one is actually registered under
  // [key] before anything is migrated.
  RegistryManager.instance.getInstance<IDualStunHandlerMigratable>(key: key);

  if (ipv4Socket != null && ipv4Socket.address.type != InternetAddressType.IPv4) {
    throw ArgumentError.value(
      ipv4Socket,
      'ipv4Socket',
      'must be bound to an IPv4 address, got ${ipv4Socket.address.type}.',
    );
  }
  if (ipv6Socket != null && ipv6Socket.address.type != InternetAddressType.IPv6) {
    throw ArgumentError.value(
      ipv6Socket,
      'ipv6Socket',
      'must be bound to an IPv6 address, got ${ipv6Socket.address.type}.',
    );
  }

  return (
    ipv4: ipv4Socket == null
        ? null
        : migrateStunHandlerSocket(ipv4Socket, key: key),
    ipv6: ipv6Socket == null
        ? null
        : migrateStunHandlerSocket(ipv6Socket, key: key),
  );
}
