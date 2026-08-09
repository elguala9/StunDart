import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/factories/dual_stun_registry_wiring.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

const injector = DualStunInjector();

String uniqueKey(String label) => '$label-${DateTime.now().microsecondsSinceEpoch}';

/// Generates a fresh unique key and runs [DualStunInjector.registerAllSingletonsStunAsync]
/// for that key, which wires real ipv4/ipv6 `RawDatagramSocket`s via
/// [connectDualStunHandlerSockets] before connecting singletons.
///
/// Use this instead of calling `registerAllSingletonsStun` directly whenever
/// a test resolves `IStunHandler`/`IStunHandlerMigratable`/`IDualStunHandler`/
/// `IDualStunHandlerMigratable` — those all depend on a `RawDatagramSocket`,
/// which is never auto-registered since it isn't `@dependencyInjectable`.
Future<String> registerStunSingletons(String label) async {
  final key = uniqueKey(label);
  await injector.registerAllSingletonsStunAsync(key: key);
  return key;
}

/// Pessimistically asserts every STUN registry slot under [key] is
/// internally congruent, for both the `ipv4` and `ipv6` subkeys:
///
/// - `IStunHandler`'s own socket is *identical* to the `RawDatagramSocket`
///   registered under the same (key, subkey) — never merely equal, never a
///   different object of the same family.
/// - Both the plain handler's socket and the registered `RawDatagramSocket`
///   are bound to the address family the subkey claims (`ipv4`/`ipv6`).
/// - `IStunHandlerMigratable`'s own socket family also matches the subkey.
/// - `IDualStunHandlerMigratable.ipv4Handler`/`.ipv6Handler` are *identical*
///   to the `IStunHandlerMigratable` registered under the matching subkey —
///   the dual handler must never drift from what the registry holds.
///
/// When [expectedIpv4Handler]/[expectedIpv6Handler]/[expectedIpv4Socket]/
/// [expectedIpv6Socket] are supplied, also asserts the live registry entry
/// for that (key, subkey) is *identical* to the given instance — use this to
/// pin down exactly which object should currently be resolved, not just that
/// "some" congruent object is.
void expectRegistryConsistent(
  String key, {
  IStunHandler? expectedIpv4Handler,
  IStunHandler? expectedIpv6Handler,
  RawDatagramSocket? expectedIpv4Socket,
  RawDatagramSocket? expectedIpv6Socket,
}) {
  final dual = RegistryManager.instance
      .getInstance<IDualStunHandlerMigratable>(key: key);

  for (final subkey in ['ipv4', 'ipv6']) {
    final expectedType = subkey == 'ipv4'
        ? InternetAddressType.IPv4
        : InternetAddressType.IPv6;

    final plainHandler = RegistryManager.instance
        .getInstance<IStunHandler>(key: key, subkey: subkey);
    final socket = RegistryManager.instance
        .getInstance<RawDatagramSocket>(key: key, subkey: subkey);
    final migratableHandler = RegistryManager.instance
        .getInstance<IStunHandlerMigratable>(key: key, subkey: subkey);

    expect(
      plainHandler.getSocket().address.type,
      expectedType,
      reason: 'IStunHandler($subkey) socket family mismatch under key $key',
    );
    expect(
      socket.address.type,
      expectedType,
      reason: 'RawDatagramSocket($subkey) family mismatch under key $key',
    );
    expect(
      identical(plainHandler.getSocket(), socket),
      isTrue,
      reason: 'IStunHandler($subkey) must use exactly the registered '
          'RawDatagramSocket($subkey) under key $key',
    );
    expect(
      migratableHandler.getSocket().address.type,
      expectedType,
      reason:
          'IStunHandlerMigratable($subkey) socket family mismatch under key $key',
    );

    final dualSlot = subkey == 'ipv4' ? dual.ipv4Handler : dual.ipv6Handler;
    expect(
      identical(dualSlot, migratableHandler),
      isTrue,
      reason: 'IDualStunHandlerMigratable.${subkey}Handler must be exactly '
          'the registered IStunHandlerMigratable($subkey) under key $key',
    );

    final expectedHandler =
        subkey == 'ipv4' ? expectedIpv4Handler : expectedIpv6Handler;
    if (expectedHandler != null) {
      expect(
        identical(plainHandler, expectedHandler),
        isTrue,
        reason: 'IStunHandler($subkey) under key $key is not the expected '
            'instance',
      );
    }

    final expectedSocket =
        subkey == 'ipv4' ? expectedIpv4Socket : expectedIpv6Socket;
    if (expectedSocket != null) {
      expect(
        identical(socket, expectedSocket),
        isTrue,
        reason:
            'RawDatagramSocket($subkey) under key $key is not the expected '
            'instance',
      );
    }
  }
}
