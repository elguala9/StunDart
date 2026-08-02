import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/generated/singleton_registry.g.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

const _injector = MainInjectionStun();

String _uniqueKey(String label) =>
    '$label-${DateTime.now().microsecondsSinceEpoch}';

void main() {
  group('registerAllSingletonsStun', () {
    test('connects IDualStunHandler to a DualStunHandler instance', () {
      final key = _uniqueKey('basic');
      _injector.registerAllSingletonsStun(key: key);

      final resolved = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: key,
      );
      expect(resolved, isA<DualStunHandler>());
    });

    test('resolves the same cached instance on repeated lookups', () {
      final key = _uniqueKey('cache');
      _injector.registerAllSingletonsStun(key: key);

      final first = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: key,
      );
      final second = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: key,
      );
      expect(identical(first, second), isTrue);
    });

    test('different keys resolve independent instances', () {
      final keyA = _uniqueKey('independent-a');
      final keyB = _uniqueKey('independent-b');
      _injector.registerAllSingletonsStun(key: keyA);
      _injector.registerAllSingletonsStun(key: keyB);

      final a = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: keyA,
      );
      final b = RegistryManager.instance.getInstance<IDualStunHandler>(
        key: keyB,
      );
      expect(identical(a, b), isFalse);
    });

    test(
      'resolved DualStunHandler picks up an IStunHandler registered under the same key/subkey',
      () async {
        final key = _uniqueKey('subkeys');
        final ipv4Socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );

        RegistryManager.instance.connectInstance<IStunHandler, StunHandler>(
          () => StunHandler.withSocket(ipv4Socket),
          key: key,
          subkey: 'ipv4',
        );
        _injector.registerAllSingletonsStun(key: key);

        final dual = RegistryManager.instance.getInstance<IDualStunHandler>(
          key: key,
        );

        expect(dual.ipv4Handler, isNotNull);
        expect(dual.ipv6Handler, isNull);

        dual.close();
        ipv4Socket.close();
      },
    );

    test('resolving an unregistered key throws RegistryNotFoundError', () {
      expect(
        () => RegistryManager.instance.getInstance<IDualStunHandler>(
          key: _uniqueKey('never-registered'),
        ),
        throwsA(isA<RegistryNotFoundError>()),
      );
    });
  });
}
