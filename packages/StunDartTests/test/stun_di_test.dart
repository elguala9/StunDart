import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/src/generated/dual_stun_handler_base_di.dart';
import 'package:stun/stun.dart';
import 'package:test/test.dart';

void _diCleanup() {
  SingletonDIAccess.remove<IDualStunHandler>();
  SingletonDIAccess.remove<DualStunHandlerBaseDI>();
}

void main() {
  group('initialPointStunWithSockets', () {
    tearDown(_diCleanup);

    test('completes with IPv4 socket only', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await expectLater(initialPointStunWithSockets(ipv4), completes);
      ipv4.close();
    });

    test('completes with IPv4 and IPv6 sockets', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await expectLater(
        initialPointStunWithSockets(ipv4, ipv6Socket: ipv6),
        completes,
      );
      ipv4.close();
      ipv6.close();
    });

    test('registers IDualStunHandler in DI', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSockets(ipv4);
      expect(() => SingletonDIAccess.get<IDualStunHandler>(), returnsNormally);
      ipv4.close();
    });

    test('DI dual handler has IPv4 handler set', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSockets(ipv4);
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(handler.ipv4Handler, isNotNull);
      ipv4.close();
    });

    test('DI dual handler has no IPv6 handler when not provided', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSockets(ipv4);
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(handler.ipv6Handler, isNull);
      ipv4.close();
    });

    test('DI dual handler has IPv6 handler when provided', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await initialPointStunWithSockets(ipv4, ipv6Socket: ipv6);
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(handler.ipv6Handler, isNotNull);
      ipv4.close();
      ipv6.close();
    });

    test('IPv4 socket type is IPv4', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSockets(ipv4);
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(
        handler.ipv4Handler!.getSocket().address.type,
        InternetAddressType.IPv4,
      );
      ipv4.close();
    });

    test('IPv6 socket type is IPv6', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final ipv6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      await initialPointStunWithSockets(ipv4, ipv6Socket: ipv6);
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(
        handler.ipv6Handler!.getSocket().address.type,
        InternetAddressType.IPv6,
      );
      ipv4.close();
      ipv6.close();
    });

    test('custom address and port are forwarded to handlers', () async {
      final ipv4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      await initialPointStunWithSockets(
        ipv4,
        address: 'stun.example.com',
        port: 3478,
      );
      // No exception thrown � address/port accepted
      expect(SingletonDIAccess.get<IDualStunHandler>().ipv4Handler, isNotNull);
      ipv4.close();
    });
  });

  group('initialPointStun', () {
    tearDown(_diCleanup);

    test('completes without throwing', () async {
      await expectLater(initialPointStun(), completes);
    });

    test('registers IDualStunHandler in DI', () async {
      await initialPointStun();
      expect(() => SingletonDIAccess.get<IDualStunHandler>(), returnsNormally);
    });

    test('DI dual handler has IPv4 handler', () async {
      await initialPointStun();
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(handler.ipv4Handler, isNotNull);
    });

    test('IPv4 handler socket is IPv4', () async {
      await initialPointStun();
      final handler = SingletonDIAccess.get<IDualStunHandler>();
      expect(
        handler.ipv4Handler!.getSocket().address.type,
        InternetAddressType.IPv4,
      );
    });

    test('second call replaces DI registrations', () async {
      await initialPointStun();
      final first = SingletonDIAccess.get<IDualStunHandler>();
      await initialPointStun();
      final second = SingletonDIAccess.get<IDualStunHandler>();
      expect(identical(first, second), isFalse);
    });
  });
}
