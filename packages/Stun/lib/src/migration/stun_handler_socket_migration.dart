import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../implementations/single/stun_handler.dart';
import '../interfaces/single/i_stun_handler.dart';
import '../interfaces/single/i_stun_handler_migratable.dart';

/// Subkey STUN handlers are registered/resolved under for a given [type].
String stunHandlerSubkeyFor(InternetAddressType type) =>
    type == InternetAddressType.IPv6 ? 'ipv6' : 'ipv4';

/// Migrates the plain [StunHandler] registered under `IStunHandler` for
/// [key] onto a fresh instance bound to [socket], resolving which subkey
/// ('ipv4'/'ipv6') to target straight from the socket's own address family.
///
/// The [IStunHandlerMigratable] already registered for that (key, subkey) is
/// never replaced — that's the whole point of the migratable variant: it
/// stays put as the live, stable source of truth, and [migrateTo] just reads
/// its current STUN server config to seed the new plain handler. Only the
/// `RawDatagramSocket` and `IStunHandler` registry entries are overwritten
/// (via [RegistryManager.setInstance]), since those are the ones meant to be
/// swapped out.
IStunHandler migrateStunHandlerSocket(
  RawDatagramSocket socket, {
  String key = 'default',
}) {
  final subkey = stunHandlerSubkeyFor(socket.address.type);
  final current = RegistryManager.instance
      .getInstance<IStunHandlerMigratable>(key: key, subkey: subkey);

  final migratedPlain = StunHandler(socket);
  current.migrateTo(migratedPlain);

  RegistryManager.instance.setInstance<RawDatagramSocket>(
    socket,
    key: key,
    subkey: subkey,
  );
  RegistryManager.instance.setInstance<IStunHandler>(
    migratedPlain,
    key: key,
    subkey: subkey,
  );

  return migratedPlain;
}

Future<IStunHandler> migrateStunHandlerSocketIpv4({
  String key = 'default',
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  return migrateStunHandlerSocket(socket);
}

Future<IStunHandler> migrateStunHandlerSocketIpv6({
  String key = 'default',
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
  return migrateStunHandlerSocket(socket);
}