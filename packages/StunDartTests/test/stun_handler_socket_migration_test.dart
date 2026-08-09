import 'dart:async';
import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

import 'support/stun_registry_test_utils.dart';

void main() {
  group('stunHandlerSubkeyFor', () {
    test('returns ipv6 for InternetAddressType.IPv6', () {
      expect(stunHandlerSubkeyFor(InternetAddressType.IPv6), 'ipv6');
    });

    test('returns ipv4 for InternetAddressType.IPv4', () {
      expect(stunHandlerSubkeyFor(InternetAddressType.IPv4), 'ipv4');
    });

    test('returns ipv4 for InternetAddressType.any (fallback)', () {
      expect(stunHandlerSubkeyFor(InternetAddressType.any), 'ipv4');
    });
  });

  group('migrateStunHandlerSocket', () {
    test(
      'replaces the plain ipv6 IStunHandler with a new one bound to the '
      'socket, carrying over the migratable handler\'s STUN server config, '
      'without touching the registered IStunHandlerMigratable',
      () async {
        final key = await registerStunSingletons('socket-migrate-ipv6');

        // Baseline: every registered slot must already be congruent before
        // anything is migrated.
        expectRegistryConsistent(key);

        final migratableBefore = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');
        migratableBefore.setStunServer(
          '2001:db8::1', // reserved (RFC 3849), never responds
          3478,
        );

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );

        final migratedPlain = migrateStunHandlerSocket(newSocket, key: key);

        final migratableAfter = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        final afterSocket = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        // The migratable is never replaced or touched by this call.
        expect(identical(migratableAfter, migratableBefore), isTrue);
        expect(
          identical(migratableAfter.getSocket(), migratableBefore.getSocket()),
          isTrue,
        );

        // Only the plain IStunHandler/RawDatagramSocket entries move.
        expect(identical(afterSocket, newSocket), isTrue);
        expect(identical(afterSocket, ipv4SocketBefore), isFalse);
        expect(identical(migratedPlain.getSocket(), newSocket), isTrue);
        expect(migratedPlain, isA<StunHandler>());
        expect(migratedPlain.getIpVersion(), InternetAddressType.IPv6);

        // Full end-state congruence check, pinned to the exact expected
        // instances: the migrated ipv6 handler/socket, and the ipv4 side
        // completely unaffected.
        expectRegistryConsistent(
          key,
          expectedIpv6Handler: migratedPlain,
          expectedIpv6Socket: newSocket,
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
        );

        // Config carried over from the migratable via migrateTo: the
        // unreachable server set above should still be in effect.
        await expectLater(
          migratedPlain.performStunRequest(),
          throwsA(isA<TimeoutException>()),
        );

        migratedPlain.close();
        migratableBefore.close();
        ipv4PlainBefore.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'replaces the plain ipv4 IStunHandler with a new one bound to the '
      'socket, carrying over the migratable handler\'s STUN server config',
      () async {
        final key = await registerStunSingletons('socket-migrate-ipv4');

        expectRegistryConsistent(key);

        final migratableBefore = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv4');
        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');
        migratableBefore.setStunServer(
          '192.0.2.1', // reserved (RFC 5737), never responds
          3478,
        );

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );

        final migratedPlain = migrateStunHandlerSocket(newSocket, key: key);

        final migratableAfter = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv4');

        expect(identical(migratableAfter, migratableBefore), isTrue);
        expect(identical(migratedPlain.getSocket(), newSocket), isTrue);
        expect(migratedPlain.getIpVersion(), InternetAddressType.IPv4);

        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migratedPlain,
          expectedIpv4Socket: newSocket,
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        // Config carried over from the migratable via migrateTo: the
        // unreachable server set above should still be in effect.
        await expectLater(
          migratedPlain.performStunRequest(),
          throwsA(isA<TimeoutException>()),
        );

        migratedPlain.close();
        migratableBefore.close();
        ipv6PlainBefore.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('throws when the ipv6 socket family has nothing registered', () async {
      final newSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv6,
        0,
      );

      expect(
        () => migrateStunHandlerSocket(newSocket, key: 'never-registered'),
        throwsA(isA<RegistryNotFoundError>()),
      );

      // Nothing must have been registered as a side effect of the failed
      // attempt: even a plain `getInstanceNullable` must come back empty.
      expect(
        RegistryManager.instance.getInstanceNullable<IStunHandler>(
          key: 'never-registered',
          subkey: 'ipv6',
        ),
        isNull,
      );
      expect(
        RegistryManager.instance.getInstanceNullable<RawDatagramSocket>(
          key: 'never-registered',
          subkey: 'ipv6',
        ),
        isNull,
      );

      newSocket.close();
    });

    test('throws when the ipv4 socket family has nothing registered', () async {
      final newSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      expect(
        () => migrateStunHandlerSocket(
          newSocket,
          key: 'never-registered-ipv4',
        ),
        throwsA(isA<RegistryNotFoundError>()),
      );

      expect(
        RegistryManager.instance.getInstanceNullable<IStunHandler>(
          key: 'never-registered-ipv4',
          subkey: 'ipv4',
        ),
        isNull,
      );
      expect(
        RegistryManager.instance.getInstanceNullable<RawDatagramSocket>(
          key: 'never-registered-ipv4',
          subkey: 'ipv4',
        ),
        isNull,
      );

      newSocket.close();
    });

    test(
      'leaves a dual handler registered on the same key untouched, since its '
      'ipv6 slot is the IStunHandlerMigratable that never gets replaced',
      () async {
        final key = await registerStunSingletons('socket-migrate-dual-ipv6');

        expectRegistryConsistent(key);

        final dual = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);
        final ipv4Before = dual.ipv4Handler;
        final ipv6Before = dual.ipv6Handler;
        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );

        final migratedPlain = migrateStunHandlerSocket(newSocket, key: key);

        expect(identical(dual.ipv6Handler, ipv6Before), isTrue);
        expect(identical(dual.ipv4Handler, ipv4Before), isTrue);
        expect(identical(migratedPlain.getSocket(), newSocket), isTrue);

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: migratedPlain,
          expectedIpv6Socket: newSocket,
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
        );

        migratedPlain.close();
        dual.close();
      },
    );

    test(
      'migrating the ipv4 slot leaves the ipv6 plain handler/socket entries alone',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-independent-families',
        );

        expectRegistryConsistent(key);

        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');
        final ipv6MigratableBefore = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');

        final newIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final migratedIpv4 = migrateStunHandlerSocket(
          newIpv4Socket,
          key: key,
        );

        final ipv6PlainAfter = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketAfter = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');
        final ipv6MigratableAfter = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');

        expect(identical(migratedIpv4.getSocket(), newIpv4Socket), isTrue);
        expect(identical(ipv6PlainAfter, ipv6PlainBefore), isTrue);
        expect(identical(ipv6SocketAfter, ipv6SocketBefore), isTrue);
        expect(identical(ipv6MigratableAfter, ipv6MigratableBefore), isTrue);

        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migratedIpv4,
          expectedIpv4Socket: newIpv4Socket,
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        migratedIpv4.close();
        ipv6PlainBefore.close();
      },
    );

    test(
      'migrating twice in a row for the same (key, subkey) both times '
      'replaces the previous plain handler',
      () async {
        final key = await registerStunSingletons('socket-migrate-twice');

        expectRegistryConsistent(key);

        final firstSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final firstMigrated = migrateStunHandlerSocket(firstSocket, key: key);

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: firstMigrated,
          expectedIpv6Socket: firstSocket,
        );

        final secondSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final secondMigrated = migrateStunHandlerSocket(
          secondSocket,
          key: key,
        );

        final afterHandler = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final afterSocket = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        expect(identical(firstMigrated, secondMigrated), isFalse);
        expect(identical(firstMigrated.getSocket(), firstSocket), isTrue);
        expect(identical(secondMigrated.getSocket(), secondSocket), isTrue);
        expect(identical(afterHandler, secondMigrated), isTrue);
        expect(identical(afterHandler, firstMigrated), isFalse);
        expect(identical(afterSocket, secondSocket), isTrue);
        expect(identical(afterSocket, firstSocket), isFalse);

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: secondMigrated,
          expectedIpv6Socket: secondSocket,
        );

        secondMigrated.close();
      },
    );

    test(
      'repeated getInstance calls after a migration keep returning the '
      'exact same migrated instance (no re-resolution via the DI factory)',
      () async {
        final key = await registerStunSingletons('socket-migrate-caching');

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final migrated = migrateStunHandlerSocket(newSocket, key: key);

        final resolvedAgain = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final resolvedYetAgain = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');

        expect(identical(migrated, resolvedAgain), isTrue);
        expect(identical(resolvedAgain, resolvedYetAgain), isTrue);
        expect(identical(migrated.getSocket(), newSocket), isTrue);

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: migrated,
          expectedIpv6Socket: newSocket,
        );

        migrated.close();
      },
    );

    test(
      'the old migratable handler keeps working on its own original socket '
      'after the plain handler is migrated onto a different one',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-old-still-works',
        );

        final migratableBefore = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        final originalSocket = migratableBefore.getSocket();

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final migratedPlain = migrateStunHandlerSocket(newSocket, key: key);

        expect(identical(migratableBefore.getSocket(), originalSocket), isTrue);
        expect(
          identical(migratableBefore.getSocket(), migratedPlain.getSocket()),
          isFalse,
        );
        expect(identical(originalSocket, newSocket), isFalse);

        final response = await migratableBefore.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv6), isNotEmpty);

        migratedPlain.close();
        migratableBefore.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'the migrated plain ipv6 handler can perform a real successful STUN '
      'request against the default server',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-functional-ipv6',
        );

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final migrated = migrateStunHandlerSocket(newSocket, key: key);

        final response = await migrated.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv6), isNotEmpty);
        expect(response.publicIp(InternetAddressType.IPv6), isNot('0.0.0.0'));

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: migrated,
          expectedIpv6Socket: newSocket,
        );

        migrated.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'the migrated plain ipv4 handler can perform a real successful STUN '
      'request against the default server',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-functional-ipv4',
        );

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final migrated = migrateStunHandlerSocket(newSocket, key: key);

        final response = await migrated.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);

        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migrated,
          expectedIpv4Socket: newSocket,
        );

        migrated.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'targets the "default" key when key is omitted',
      () async {
        await injector.registerAllSingletonsStunAsync(key: 'default');

        addTearDown(
          () => RegistryManager.instance
              .getInstance<IDualStunHandlerMigratable>(key: 'default')
              .close(),
        );

        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: 'default', subkey: 'ipv4');

        final newSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );

        final migrated = migrateStunHandlerSocket(newSocket);

        expect(identical(migrated.getSocket(), newSocket), isTrue);
        expectRegistryConsistent(
          'default',
          expectedIpv6Handler: migrated,
          expectedIpv6Socket: newSocket,
          expectedIpv4Handler: ipv4PlainBefore,
        );

        migrated.close();
        ipv4PlainBefore.close();
      },
    );
  });

  group('migrateStunHandlerSocketIpv4', () {
    test(
      'binds a fresh ipv4 socket and migrates it under the given key',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-helper-ipv4',
        );

        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        final migrated = await migrateStunHandlerSocketIpv4(key: key);

        expect(migrated.getIpVersion(), InternetAddressType.IPv4);

        // The key must actually be honored, not silently defaulted.
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migrated,
          expectedIpv4Socket: migrated.getSocket(),
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        migrated.close();
        ipv6PlainBefore.close();
      },
    );

    test(
      'throws when nothing is registered under the given key',
      () async {
        expect(
          () => migrateStunHandlerSocketIpv4(
            key: 'ipv4-helper-never-registered',
          ),
          throwsA(isA<RegistryNotFoundError>()),
        );
      },
    );
  });

  group('migrateStunHandlerSocketIpv6', () {
    test(
      'binds a fresh ipv6 socket and migrates it under the given key',
      () async {
        final key = await registerStunSingletons(
          'socket-migrate-helper-ipv6',
        );

        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');

        final migrated = await migrateStunHandlerSocketIpv6(key: key);

        expect(migrated.getIpVersion(), InternetAddressType.IPv6);

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: migrated,
          expectedIpv6Socket: migrated.getSocket(),
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
        );

        migrated.close();
        ipv4PlainBefore.close();
      },
    );

    test(
      'throws when nothing is registered under the given key',
      () async {
        expect(
          () => migrateStunHandlerSocketIpv6(
            key: 'ipv6-helper-never-registered',
          ),
          throwsA(isA<RegistryNotFoundError>()),
        );
      },
    );
  });
}
