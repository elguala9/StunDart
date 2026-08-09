import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

import 'support/stun_registry_test_utils.dart';

void main() {
  group('migrateDualStunHandlerSockets', () {
    test(
      'migrates both the ipv4 and ipv6 plain IStunHandler slots in one call, '
      'without touching the dual handler\'s migratable slots',
      () async {
        final key = await registerStunSingletons('dual-migrate-both');

        expectRegistryConsistent(key);

        final dual = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);
        final ipv4Before = dual.ipv4Handler;
        final ipv6Before = dual.ipv6Handler;
        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');

        final newIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final newIpv6Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );

        final migrated = migrateDualStunHandlerSockets(
          ipv4Socket: newIpv4Socket,
          ipv6Socket: newIpv6Socket,
          key: key,
        );

        expect(identical(migrated.ipv4!.getSocket(), newIpv4Socket), isTrue);
        expect(identical(migrated.ipv6!.getSocket(), newIpv6Socket), isTrue);
        expect(migrated.ipv4!.getIpVersion(), InternetAddressType.IPv4);
        expect(migrated.ipv6!.getIpVersion(), InternetAddressType.IPv6);
        expect(identical(migrated.ipv4, ipv4PlainBefore), isFalse);
        expect(identical(migrated.ipv6, ipv6PlainBefore), isFalse);

        // The dual handler's own slots are never replaced.
        expect(identical(dual.ipv4Handler, ipv4Before), isTrue);
        expect(identical(dual.ipv6Handler, ipv6Before), isTrue);

        // The registry itself reflects the same new instances, and every
        // slot (including the untouched migratable graph) stays congruent.
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migrated.ipv4,
          expectedIpv4Socket: newIpv4Socket,
          expectedIpv6Handler: migrated.ipv6,
          expectedIpv6Socket: newIpv6Socket,
        );

        migrated.ipv4!.close();
        migrated.ipv6!.close();
        ipv4PlainBefore.close();
        ipv6PlainBefore.close();
        dual.close();
      },
    );

    test('migrates only the ipv6 slot when ipv4Socket is omitted', () async {
      final key = await registerStunSingletons('dual-migrate-ipv6-only');

      expectRegistryConsistent(key);

      final ipv4PlainBefore = RegistryManager.instance
          .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
      final ipv4SocketBefore = RegistryManager.instance
          .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');

      final newIpv6Socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv6,
        0,
      );

      final migrated = migrateDualStunHandlerSockets(
        ipv6Socket: newIpv6Socket,
        key: key,
      );

      expect(migrated.ipv4, isNull);
      expect(identical(migrated.ipv6!.getSocket(), newIpv6Socket), isTrue);

      // The ipv4 slot is left completely alone, and both families stay
      // congruent end to end.
      expectRegistryConsistent(
        key,
        expectedIpv4Handler: ipv4PlainBefore,
        expectedIpv4Socket: ipv4SocketBefore,
        expectedIpv6Handler: migrated.ipv6,
        expectedIpv6Socket: newIpv6Socket,
      );

      migrated.ipv6!.close();
      ipv4PlainBefore.close();
    });

    test('migrates only the ipv4 slot when ipv6Socket is omitted', () async {
      final key = await registerStunSingletons('dual-migrate-ipv4-only');

      expectRegistryConsistent(key);

      final ipv6PlainBefore = RegistryManager.instance
          .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
      final ipv6SocketBefore = RegistryManager.instance
          .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

      final newIpv4Socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      final migrated = migrateDualStunHandlerSockets(
        ipv4Socket: newIpv4Socket,
        key: key,
      );

      expect(migrated.ipv6, isNull);
      expect(identical(migrated.ipv4!.getSocket(), newIpv4Socket), isTrue);

      expectRegistryConsistent(
        key,
        expectedIpv4Handler: migrated.ipv4,
        expectedIpv4Socket: newIpv4Socket,
        expectedIpv6Handler: ipv6PlainBefore,
        expectedIpv6Socket: ipv6SocketBefore,
      );

      migrated.ipv4!.close();
      ipv6PlainBefore.close();
    });

    test('throws when neither socket is passed', () async {
      final key = await registerStunSingletons('dual-migrate-none');

      final ipv4PlainBefore = RegistryManager.instance
          .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
      final ipv4SocketBefore = RegistryManager.instance
          .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');
      final ipv6PlainBefore = RegistryManager.instance
          .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
      final ipv6SocketBefore = RegistryManager.instance
          .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

      expect(
        () => migrateDualStunHandlerSockets(key: key),
        throwsA(isA<ArgumentError>()),
      );

      // A rejected call must leave absolutely everything untouched.
      expectRegistryConsistent(
        key,
        expectedIpv4Handler: ipv4PlainBefore,
        expectedIpv4Socket: ipv4SocketBefore,
        expectedIpv6Handler: ipv6PlainBefore,
        expectedIpv6Socket: ipv6SocketBefore,
      );

      ipv4PlainBefore.close();
      ipv6PlainBefore.close();
    });

    test(
      'throws when ipv4Socket does not carry an IPv4 address',
      () async {
        final key = await registerStunSingletons('dual-migrate-mismatch-ipv4');

        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');

        final wrongFamilySocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );

        expect(
          () => migrateDualStunHandlerSockets(
            ipv4Socket: wrongFamilySocket,
            key: key,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              'ipv4Socket',
            ),
          ),
        );

        expectRegistryConsistent(
          key,
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
        );

        wrongFamilySocket.close();
        ipv4PlainBefore.close();
      },
    );

    test(
      'throws when ipv6Socket does not carry an IPv6 address',
      () async {
        final key = await registerStunSingletons('dual-migrate-mismatch-ipv6');

        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        final wrongFamilySocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );

        expect(
          () => migrateDualStunHandlerSockets(
            ipv6Socket: wrongFamilySocket,
            key: key,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              'ipv6Socket',
            ),
          ),
        );

        expectRegistryConsistent(
          key,
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        wrongFamilySocket.close();
        ipv6PlainBefore.close();
      },
    );

    test(
      'a family mismatch on one socket leaves the other slot completely '
      'unmigrated (validated atomically before anything moves)',
      () async {
        final key = await registerStunSingletons(
          'dual-migrate-atomic-validation',
        );

        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');
        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        final validIpv6Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final invalidIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6, // wrong family on purpose
          0,
        );

        expect(
          () => migrateDualStunHandlerSockets(
            ipv4Socket: invalidIpv4Socket,
            ipv6Socket: validIpv6Socket,
            key: key,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Neither family may have moved: the valid ipv6 socket must NOT
        // have been consumed just because ipv4 failed validation first.
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        validIpv6Socket.close();
        invalidIpv4Socket.close();
        ipv4PlainBefore.close();
        ipv6PlainBefore.close();
      },
    );

    test(
      'a family mismatch on ipv6 leaves a valid ipv4 socket unmigrated too '
      '(both checks run before either family is touched, regardless of '
      'which one is invalid)',
      () async {
        final key = await registerStunSingletons(
          'dual-migrate-atomic-validation-reverse',
        );

        final ipv4PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv4');
        final ipv4SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv4');
        final ipv6PlainBefore = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        final ipv6SocketBefore = RegistryManager.instance
            .getInstance<RawDatagramSocket>(key: key, subkey: 'ipv6');

        final validIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final invalidIpv6Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, // wrong family on purpose
          0,
        );

        expect(
          () => migrateDualStunHandlerSockets(
            ipv4Socket: validIpv4Socket,
            ipv6Socket: invalidIpv6Socket,
            key: key,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Neither family may have moved: the valid ipv4 socket must NOT
        // have been consumed just because ipv6 failed validation second.
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: ipv4PlainBefore,
          expectedIpv4Socket: ipv4SocketBefore,
          expectedIpv6Handler: ipv6PlainBefore,
          expectedIpv6Socket: ipv6SocketBefore,
        );

        validIpv4Socket.close();
        invalidIpv6Socket.close();
        ipv4PlainBefore.close();
        ipv6PlainBefore.close();
      },
    );

    test('throws when nothing is registered under the given key', () async {
      final newSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv6,
        0,
      );

      expect(
        () => migrateDualStunHandlerSockets(
          ipv6Socket: newSocket,
          key: 'dual-never-registered',
        ),
        throwsA(isA<RegistryNotFoundError>()),
      );

      expect(
        RegistryManager.instance.getInstanceNullable<IStunHandler>(
          key: 'dual-never-registered',
          subkey: 'ipv6',
        ),
        isNull,
      );
      expect(
        RegistryManager.instance.getInstanceNullable<RawDatagramSocket>(
          key: 'dual-never-registered',
          subkey: 'ipv6',
        ),
        isNull,
      );

      newSocket.close();
    });

    test(
      'the dual handler itself keeps answering STUN requests via its '
      'untouched migratable slots after both plain slots are migrated',
      () async {
        final key = await registerStunSingletons(
          'dual-migrate-still-functional',
        );

        final dual = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);

        final newIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final newIpv6Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final migrated = migrateDualStunHandlerSockets(
          ipv4Socket: newIpv4Socket,
          ipv6Socket: newIpv6Socket,
          key: key,
        );

        final response = await dual.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
        expect(response.publicIp(InternetAddressType.IPv6), isNotEmpty);

        expectRegistryConsistent(
          key,
          expectedIpv4Handler: migrated.ipv4,
          expectedIpv4Socket: newIpv4Socket,
          expectedIpv6Handler: migrated.ipv6,
          expectedIpv6Socket: newIpv6Socket,
        );

        migrated.ipv4!.close();
        migrated.ipv6!.close();
        dual.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'migrating sequentially (ipv4 first, then ipv6) is equivalent to '
      'migrating both at once',
      () async {
        final key = await registerStunSingletons('dual-migrate-sequential');

        expectRegistryConsistent(key);

        final newIpv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final firstResult = migrateDualStunHandlerSockets(
          ipv4Socket: newIpv4Socket,
          key: key,
        );

        // After the first (ipv4-only) call, ipv6 must still be whatever it
        // was at registration time.
        final ipv6PlainMid = RegistryManager.instance
            .getInstance<IStunHandler>(key: key, subkey: 'ipv6');
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: firstResult.ipv4,
          expectedIpv4Socket: newIpv4Socket,
          expectedIpv6Handler: ipv6PlainMid,
        );

        final newIpv6Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
        );
        final secondResult = migrateDualStunHandlerSockets(
          ipv6Socket: newIpv6Socket,
          key: key,
        );

        expect(identical(firstResult.ipv4!.getSocket(), newIpv4Socket), isTrue);
        expect(
          identical(secondResult.ipv6!.getSocket(), newIpv6Socket),
          isTrue,
        );

        // Final state: ipv4 from the first call, ipv6 from the second —
        // both must still be exactly what each call produced.
        expectRegistryConsistent(
          key,
          expectedIpv4Handler: firstResult.ipv4,
          expectedIpv4Socket: newIpv4Socket,
          expectedIpv6Handler: secondResult.ipv6,
          expectedIpv6Socket: newIpv6Socket,
        );

        firstResult.ipv4!.close();
        secondResult.ipv6!.close();
      },
    );
  });
}
