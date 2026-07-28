import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/implementations/dual/dual_stun_handler_base.dart';
import 'package:stun/src/initial_point/initial_point_registry.dart';
import 'package:stun/src/interfaces/i_stun_handler_base.dart';
import 'package:test/test.dart';

const _key1 = 'primary';
const _key2 = 'secondary';

void _cleanup() {
  RegistryAccess.unregister<IStunHandlerBase>(_key1);
  RegistryAccess.unregister<IStunHandlerBase>(_key2);
}

void main() {
  group('initialPointStunWithSocketsRegistry', () {
    tearDown(_cleanup);

    test('completes with IPv4 socket only', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await expectLater(
        initialPointStunWithSocketsRegistry(_key1, ipv4),
        completes,
      );
      ipv4.close();
    });

    test('completes with IPv4 and IPv6 sockets', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await expectLater(
        initialPointStunWithSocketsRegistry(_key1, ipv4, ipv6Socket: ipv6),
        completes,
      );
      ipv4.close();
      ipv6.close();
    });

    test('registers IStunHandlerBase under the given key', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      expect(RegistryAccess.contains<IStunHandlerBase>(_key1), isTrue);
      ipv4.close();
    });

    test('does not register under a different key', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      expect(RegistryAccess.contains<IStunHandlerBase>(_key2), isFalse);
      ipv4.close();
    });

    test('getInstance returns the registered handler', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      expect(
        () => RegistryAccess.getInstance<IStunHandlerBase>(_key1),
        returnsNormally,
      );
      ipv4.close();
    });

    test('registered handler has IPv4 handler set', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(stun.dualHandler.ipv4Handler, isNotNull);
      ipv4.close();
    });

    test('registered handler has no IPv6 handler when not provided', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(stun.dualHandler.ipv6Handler, isNull);
      ipv4.close();
    });

    test('registered handler has IPv6 handler when provided', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4, ipv6Socket: ipv6);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(stun.dualHandler.ipv6Handler, isNotNull);
      ipv4.close();
      ipv6.close();
    });

    test('IPv4 socket type is IPv4', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(
        stun.dualHandler.ipv4Handler!.getSocket().address.type,
        InternetAddressType.IPv4,
      );
      ipv4.close();
    });

    test('IPv6 socket type is IPv6', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4, ipv6Socket: ipv6);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(
        stun.dualHandler.ipv6Handler!.getSocket().address.type,
        InternetAddressType.IPv6,
      );
      ipv4.close();
      ipv6.close();
    });

    test('custom address and port are forwarded to IPv4 handler', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(
        _key1,
        ipv4,
        address: 'stun.example.com',
        port: 3478,
      );
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(stun.dualHandler.ipv4Handler, isNotNull);
      ipv4.close();
    });

    test('different keys register independent instances', () async {
      final ipv4a = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv4b = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4a);
      await initialPointStunWithSocketsRegistry(_key2, ipv4b);
      final s1 = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      final s2 = RegistryAccess.getInstance<IStunHandlerBase>(_key2);
      expect(identical(s1, s2), isFalse);
      ipv4a.close();
      ipv4b.close();
    });

    test('second call on same key replaces the registration', () async {
      final ipv4a = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv4b = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4a);
      final first = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      await initialPointStunWithSocketsRegistry(_key1, ipv4b);
      final second = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      expect(identical(first, second), isFalse);
      ipv4a.close();
      ipv4b.close();
    });

    test('destroy() closes all handlers without throwing', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSocketsRegistry(_key1, ipv4);
      final stun = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      expect(() => stun.destroy(), returnsNormally);
      ipv4.close();
    });
  });

  group('initialPointStunRegistry', () {
    tearDown(_cleanup);

    test('completes without throwing', () async {
      await expectLater(initialPointStunRegistry(_key1), completes);
    });

    test('registers IStunHandlerBase under the given key', () async {
      await initialPointStunRegistry(_key1);
      expect(RegistryAccess.contains<IStunHandlerBase>(_key1), isTrue);
    });

    test('getInstance returns the registered handler', () async {
      await initialPointStunRegistry(_key1);
      expect(
        () => RegistryAccess.getInstance<IStunHandlerBase>(_key1),
        returnsNormally,
      );
    });

    test('registered handler has IPv4 handler', () async {
      await initialPointStunRegistry(_key1);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(stun.dualHandler.ipv4Handler, isNotNull);
    });

    test('IPv4 handler socket is IPv4', () async {
      await initialPointStunRegistry(_key1);
      final stun =
          RegistryAccess.getInstance<IStunHandlerBase>(_key1)
              as DualStunHandlerBase;
      expect(
        stun.dualHandler.ipv4Handler!.getSocket().address.type,
        InternetAddressType.IPv4,
      );
    });

    test('different keys create independent instances', () async {
      await initialPointStunRegistry(_key1);
      await initialPointStunRegistry(_key2);
      final s1 = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      final s2 = RegistryAccess.getInstance<IStunHandlerBase>(_key2);
      expect(identical(s1, s2), isFalse);
    });

    test('second call on same key replaces the registration', () async {
      await initialPointStunRegistry(_key1);
      final first = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      await initialPointStunRegistry(_key1);
      final second = RegistryAccess.getInstance<IStunHandlerBase>(_key1);
      expect(identical(first, second), isFalse);
    });
  });
}
