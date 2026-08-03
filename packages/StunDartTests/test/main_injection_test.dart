import 'dart:async';
import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/main_injection.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

import 'support/stun_registry_test_utils.dart';

void main() {
  group('registerAllSingletonsStun (main_injection.dart)', () {
    test('connects IDualStunHandler to a DualStunHandler instance', () async {
      final key = await registerStunSingletons('dual-basic');

      final dual = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: key,
      );

      expect(dual, isA<DualStunHandler>());
      expect(dual.ipv4Handler, isNotNull);
      expect(dual.ipv6Handler, isNotNull);
      expect(dual.ipv4Handler!.getIpVersion().toString(), contains('IPv4'));
      expect(dual.ipv6Handler!.getIpVersion().toString(), contains('IPv6'));

      dual.close();
    });

    test(
      'connects IDualStunHandlerMigratable to a DualStunHandlerMigratable instance',
      () async {
        final key = await registerStunSingletons('dual-migratable-basic');

        final dual = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);

        expect(dual, isA<DualStunHandlerMigratable>());
        expect(dual.ipv4Handler, isNotNull);
        expect(dual.ipv6Handler, isNotNull);

        dual.close();
      },
    );

    test(
      'connects IStunHandler under the ipv4 and ipv6 subkeys to independent StunHandler instances',
      () async {
        final key = await registerStunSingletons('single-subkeys');

        final ipv4 = RegistryManager.instance.getInstance<IStunHandler>(
          key: key,
          subkey: 'ipv4',
        );
        final ipv6 = RegistryManager.instance.getInstance<IStunHandler>(
          key: key,
          subkey: 'ipv6',
        );

        expect(ipv4, isA<StunHandler>());
        expect(ipv6, isA<StunHandler>());
        expect(ipv4.getIpVersion().toString(), contains('IPv4'));
        expect(ipv6.getIpVersion().toString(), contains('IPv6'));
        expect(identical(ipv4, ipv6), isFalse);

        ipv4.close();
        ipv6.close();
      },
    );

    test(
      'connects IStunHandlerMigratable under the ipv4 and ipv6 subkeys to independent StunHandlerMigratable instances',
      () async {
        final key = await registerStunSingletons('single-migratable-subkeys');

        final ipv4 = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv4');
        final ipv6 = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');

        expect(ipv4, isA<StunHandlerMigratable>());
        expect(ipv6, isA<StunHandlerMigratable>());
        expect(ipv4.getIpVersion().toString(), contains('IPv4'));
        expect(ipv6.getIpVersion().toString(), contains('IPv6'));
        expect(identical(ipv4, ipv6), isFalse);

        ipv4.close();
        ipv6.close();
      },
    );

    test(
      'resolving IDualStunHandler without wiring the socket first throws RegistryNotFoundError',
      () {
        final key = uniqueKey('dual-unwired');
        injector.registerAllSingletonsStun(key: key);

        expect(
          () =>
              RegistryManager.instance.getInstance<IDualStunHandler>(
                key: key,
              ),
          throwsA(isA<RegistryNotFoundError>()),
        );
      },
    );

    test(
      'resolving IStunHandler without wiring the socket first throws RegistryNotFoundError',
      () {
        final key = uniqueKey('single-unwired');
        injector.registerAllSingletonsStun(key: key);

        expect(
          () => RegistryManager.instance.getInstance<IStunHandler>(
            key: key,
            subkey: 'ipv4',
          ),
          throwsA(isA<RegistryNotFoundError>()),
        );
      },
    );

    test(
      'IStunHandler and IStunHandlerMigratable share the same socket when registered under the same key/subkey',
      () async {
        final key = await registerStunSingletons('shared-socket');

        final handler = RegistryManager.instance.getInstance<IStunHandler>(
          key: key,
          subkey: 'ipv6',
        );
        final migratable = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');

        expect(handler.getSocket(), same(migratable.getSocket()));

        handler.close();
        migratable.close();
      },
    );

    test(
      'resolves the same cached instance on repeated lookups for every registered type',
      () async {
        final key = await registerStunSingletons('cache-all-types');

        final dual1 = RegistryManager.instance.getInstance<IDualStunHandler>(
          key: key,
        );
        final dual2 = RegistryManager.instance.getInstance<IDualStunHandler>(
          key: key,
        );
        expect(identical(dual1, dual2), isTrue);

        final dualMigratable1 = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);
        final dualMigratable2 = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: key);
        expect(identical(dualMigratable1, dualMigratable2), isTrue);

        final single1 = RegistryManager.instance.getInstance<IStunHandler>(
          key: key,
          subkey: 'ipv4',
        );
        final single2 = RegistryManager.instance.getInstance<IStunHandler>(
          key: key,
          subkey: 'ipv4',
        );
        expect(identical(single1, single2), isTrue);

        final singleMigratable1 = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        final singleMigratable2 = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        expect(identical(singleMigratable1, singleMigratable2), isTrue);

        dual1.close();
      },
    );

    test('different keys resolve independent instances for every type', () async {
      final keyA = await registerStunSingletons('independent-a');
      final keyB = await registerStunSingletons('independent-b');

      final dualA = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: keyA,
      );
      final dualB = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: keyB,
      );
      expect(identical(dualA, dualB), isFalse);

      final singleA = RegistryManager.instance.getInstance<IStunHandler>(
        key: keyA,
        subkey: 'ipv4',
      );
      final singleB = RegistryManager.instance.getInstance<IStunHandler>(
        key: keyB,
        subkey: 'ipv4',
      );
      expect(identical(singleA, singleB), isFalse);

      dualA.close();
      dualB.close();
    });

    test(
      'IDualStunHandler default type parameter operates on the ipv6 slot (ipv6 is primary per project convention)',
      () async {
        final key = await registerStunSingletons('ipv6-priority');

        final dual = RegistryManager.instance.getInstance<IDualStunHandler>(
          key: key,
        );

        expect(dual.getHandler(), same(dual.ipv6Handler));
        expect(dual.getSocket(), same(dual.ipv6Handler!.getSocket()));

        dual.close();
      },
    );

    test(
      'DualStunHandlerMigratable.migrateTo copies ipv4/ipv6 profiles into a plain DualStunHandler',
      () async {
        final sourceKey = await registerStunSingletons('migrate-source');
        final targetKey = await registerStunSingletons('migrate-target');

        final source = RegistryManager.instance
            .getInstance<IDualStunHandlerMigratable>(key: sourceKey);
        final target = RegistryManager.instance.getInstance<IDualStunHandler>(
          key: targetKey,
        );

        expect(() => source.migrateTo(target), returnsNormally);

        // Post-migration, the target must remain usable via the interface
        // it was resolved as (not just "didn't throw during the copy").
        expect(() => target.getSocket(), returnsNormally);

        source.close();
        target.close();
      },
    );

    test(
      'StunHandlerMigratable.migrateTo copies its profile into a plain StunHandler',
      () async {
        final key = await registerStunSingletons('migrate-single');

        final migratable = RegistryManager.instance
            .getInstance<IStunHandlerMigratable>(key: key, subkey: 'ipv6');
        // The migratable's own socket family is irrelevant here: applyTo
        // only ever copies stunAddress/stunPort onto the target (see
        // StunHandlerProfile.applyTo), so the target is free to be IPv4 —
        // that also keeps this regression check independent of IPv6
        // reachability in the test environment.
        final ipv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        final target = StunHandler(
          ipv4Socket,
          address: '192.0.2.1', // reserved, never responds
          port: 3478,
          timeout: const Duration(seconds: 2),
        );

        // Forces the target to build/use its request handler once against
        // the unreachable server, before migration overwrites it.
        await expectLater(
          target.performStunRequest(),
          throwsA(isA<TimeoutException>()),
        );

        expect(() => migratable.migrateTo(target), returnsNormally);

        // Regression guard: if the target's request handler had frozen the
        // pre-migration server on its first access above, this would time
        // out again instead of succeeding with the migrated server.
        final response = await target.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);

        target.close();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'beforeRegisterAllSingletonsStun / afterRegisterAllSingletonsStun hooks fire around registration',
      () {
        final calls = <String>[];
        final recordingInjector = _RecordingMainInjectionStun(calls);
        final key = uniqueKey('hooks');

        recordingInjector.registerAllSingletonsStun(key: key);

        expect(calls, ['before:$key', 'after:$key']);
      },
    );
  });
}

class _RecordingMainInjectionStun with MainInjectionStunMixin {
  _RecordingMainInjectionStun(this._calls);

  final List<String> _calls;

  @override
  void beforeRegisterAllSingletonsStun({String key = 'default'}) {
    _calls.add('before:$key');
  }

  @override
  void afterRegisterAllSingletonsStun({String key = 'default'}) {
    _calls.add('after:$key');
  }
}
