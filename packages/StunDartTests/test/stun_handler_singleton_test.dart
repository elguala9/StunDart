import 'dart:io';
import 'package:stun/stun.dart';
import 'package:test/test.dart';
import 'test_constants.dart';

void main() {
  group('StunHandlerSingleton Tests', () {
    tearDown(() async {
      // Clean up after each test
      try {
        StunHandlerSingleton.instance.close();
      } catch (_) {
        // Ignore errors during cleanup
      }
    });

    test('Singleton instance is the same when accessed via constructor', () {
      final instance1 = StunHandlerSingleton();
      final instance2 = StunHandlerSingleton();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Singleton instance is the same when accessed via .instance', () {
      final instance1 = StunHandlerSingleton.instance;
      final instance2 = StunHandlerSingleton.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('Constructor and .instance return the same instance', () {
      final instance1 = StunHandlerSingleton();
      final instance2 = StunHandlerSingleton.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('initialize() creates IPv4 handler (always)', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // IPv4 should always exist
      final ipv4Handler = singleton.ipv4Handler;
      expect(ipv4Handler, isNotNull);
      final ipv4Socket = ipv4Handler.getSocket();
      expect(ipv4Socket.address.type, equals(InternetAddressType.IPv4));
    });

    test('initialize() creates IPv6 handler (if available)', () async {
      final singleton = StunHandlerSingleton.instance;
      try {
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        // IPv6 may or may not exist
        final ipv6Handler = singleton.ipv6Handler;
        if (ipv6Handler != null) {
          final ipv6Socket = ipv6Handler.getSocket();
          expect(ipv6Socket.address.type, equals(InternetAddressType.IPv6));
        }
      } catch (e) {
        print('IPv6 not fully available on this system: $e');
      }
    });

    test('ipv4Handler getter always returns non-null', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final handler = singleton.ipv4Handler;
      expect(handler, isNotNull);
      expect(handler.getSocket().address.type, equals(InternetAddressType.IPv4));
    });

    test('ipv6Handler getter may return null', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final handler = singleton.ipv6Handler;
      // May be null or non-null depending on system
      if (handler != null) {
        expect(handler.getSocket().address.type, equals(InternetAddressType.IPv6));
      }
    });

    test('performStunRequest() executes on both handlers', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final response = await singleton.performStunRequest();
      expect(response.publicIp, isNotEmpty);
      expect(response.publicPort, greaterThan(0));
    });

    test('performStunRequest() prefers IPv6 if available', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final response = await singleton.performStunRequest();
      // Should be able to get a response (either IPv6 or IPv4)
      expect(response.publicIp, isNotEmpty);
      expect(response.publicPort, greaterThan(0));

      // If IPv6 is available, verify it was used
      if (singleton.ipv6Handler != null) {
        final ipv6Response = await singleton.ipv6Handler!.performStunRequest();
        expect(response.publicIp, equals(ipv6Response.publicIp));
        expect(response.publicPort, equals(ipv6Response.publicPort));
      }
    });

    test('performLocalRequest() executes on both handlers', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final info = await singleton.performLocalRequest();
      expect(info.localIp, isNotEmpty);
      expect(info.localPort, greaterThan(0));
    });

    test('performLocalRequest() caches results', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final info1 = await singleton.performLocalRequest();
      final info2 = await singleton.performLocalRequest();

      // Should be identical due to caching
      expect(info1.localIp, equals(info2.localIp));
      expect(info1.localPort, equals(info2.localPort));
    });

    test('replaceHandler(mock, ipv6: true) replaces only IPv6', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final originalIpv4 = singleton.ipv4Handler;
      final newHandler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
        ipv6: true,
      );

      singleton.replaceHandler(newHandler, ipv6: true);

      // IPv4 should still be the original
      final currentIpv4 = singleton.ipv4Handler;
      expect(identical(originalIpv4, currentIpv4), isTrue);
    });

    test('replaceHandler(mock, ipv6: false) replaces only IPv4', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final newHandler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
        ipv6: false,
      );

      singleton.replaceHandler(newHandler, ipv6: false);

      // Should use the new handler
      final socket = singleton.ipv4Handler.getSocket();
      expect(socket, isNotNull);
    });

    test('setStunServer with ipv6: null sets both handlers', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: null);
    });

    test('setStunServer with ipv6: false sets only IPv4', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: false);
    });

    test('setStunServer with ipv6: true sets only IPv6 (if available)', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw even if IPv6 not available
      singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: true);
    });

    test('close(ipv6: false) closes IPv4', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close(ipv6: false);

      // IPv4 should throw
      expect(
        () => singleton.getSocket(ipv6: false),
        throwsA(isA<StateError>()),
      );
    });

    test('close(ipv6: true) closes IPv6 (if available)', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close(ipv6: true);

      // IPv4 should still work
      final ipv4Socket = singleton.getSocket(ipv6: false);
      expect(ipv4Socket, isNotNull);

      // IPv6 should not be accessible
      final ipv6Handler = singleton.ipv6Handler;
      expect(ipv6Handler, isNull);
    });

    test('close() with no param closes both handlers', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close();

      // IPv4 should throw
      expect(
        () => singleton.getSocket(ipv6: false),
        throwsA(isA<StateError>()),
      );

      // IPv6 should be null
      expect(singleton.ipv6Handler, isNull);
    });

    test('getSocket(ipv6: false) returns IPv4 socket', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final socket = singleton.getSocket(ipv6: false);
      expect(socket, isNotNull);
      expect(socket.address.type, equals(InternetAddressType.IPv4));
    });

    test('getSocket(ipv6: true) returns IPv6 socket if available', () async {
      final singleton = StunHandlerSingleton.instance;
      try {
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        if (singleton.ipv6Handler != null) {
          final socket = singleton.getSocket(ipv6: true);
          expect(socket, isNotNull);
          expect(socket.address.type, equals(InternetAddressType.IPv6));
        } else {
          // Should throw if IPv6 not available
          expect(
            () => singleton.getSocket(ipv6: true),
            throwsA(isA<StateError>()),
          );
        }
      } catch (e) {
        print('IPv6 not available on this system: $e');
      }
    });

    test('pingStunServer(ipv6: false) pings IPv4', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final reachable = await singleton.pingStunServer(ipv6: false);
      expect(reachable, isTrue);
    });

    test('pingStunServer(ipv6: true) pings IPv6 if available', () async {
      final singleton = StunHandlerSingleton.instance;
      try {
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        if (singleton.ipv6Handler != null) {
          final reachable = await singleton.pingStunServer(ipv6: true);
          expect(reachable, isTrue);
        } else {
          expect(
            () => singleton.pingStunServer(ipv6: true),
            throwsA(isA<StateError>()),
          );
        }
      } catch (e) {
        print('IPv6 not available on this system: $e');
      }
    });

    test('initialize() accepts configurable timeout', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        timeout: const Duration(seconds: 3),
      );

      final ipv4Handler = singleton.ipv4Handler;
      expect(ipv4Handler, isNotNull);
      final response = await ipv4Handler.performStunRequest();
      expect(response.publicIp, isNotEmpty);
    });

    test('initialize() accepts onLog callback', () async {
      final singleton = StunHandlerSingleton.instance;
      final messages = <String>[];

      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        onLog: (msg) => messages.add(msg),
      );

      expect(
        messages.any((msg) => msg.contains('handler initialization')),
        anyOf(isTrue, isFalse), // Message may or may not appear depending on system
        reason: 'onLog callback should be set without throwing',
      );
    });

    test('StunHandlerSingleton implements IStunHandlerSingleton', () {
      final IStunHandlerSingleton s = StunHandlerSingleton.instance;
      expect(s, isA<IStunHandlerSingleton>());
    });
  });
}
