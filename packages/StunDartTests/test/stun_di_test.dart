import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

String _uniqueKey(String label) =>
    '$label-${DateTime.now().microsecondsSinceEpoch}';

void main() {
  group('DualStunHandler.dependencyInjectionFactory subkey resolution', () {
    test('resolves ipv4Handler and ipv6Handler from their own subkeys', () async {
      final key = _uniqueKey('dual-handler');
      final ipv4Socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      final ipv6Socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv6,
        0,
      );

      RegistryManager.instance
        ..connectInstance<IStunHandler, StunHandler>(
          () => StunHandler.withSocket(ipv4Socket),
          key: key,
          subkey: 'ipv4',
        )
        ..connectInstance<IStunHandler, StunHandler>(
          () => StunHandler.withSocket(ipv6Socket),
          key: key,
          subkey: 'ipv6',
        );

      final dual = DualStunHandler.dependencyInjectionFactory(key: key);

      expect(dual.ipv4Handler, isNotNull);
      expect(dual.ipv6Handler, isNotNull);
      expect(
        dual.ipv4Handler!.getSocket().address.type,
        InternetAddressType.IPv4,
      );
      expect(
        dual.ipv6Handler!.getSocket().address.type,
        InternetAddressType.IPv6,
      );

      dual.destroy();
      ipv4Socket.close();
      ipv6Socket.close();
    });

    test('leaves a handler null when only one subkey is connected', () async {
      final key = _uniqueKey('dual-handler-single');
      final ipv4Socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      RegistryManager.instance.connectInstance<IStunHandler, StunHandler>(
        () => StunHandler.withSocket(ipv4Socket),
        key: key,
        subkey: 'ipv4',
      );

      final dual = DualStunHandler.dependencyInjectionFactory(key: key);

      expect(dual.ipv4Handler, isNotNull);
      expect(dual.ipv6Handler, isNull);

      dual.destroy();
      ipv4Socket.close();
    });
  });
}
