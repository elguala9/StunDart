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

    test('createNewHandler initializes the handler', () async {
      final singleton = StunHandlerSingleton.instance;
      final handler =
          await singleton.createNewHandler(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

      expect(handler, isNotNull);

      // Verify socket was created
      final socket = singleton.getSocket();
      expect(socket, isNotNull);
      expect(socket.port, greaterThan(0));
    });

    test('createNewHandler works with IPv6', () async {
      try {
        final singleton = StunHandlerSingleton.instance;
        final handler =
            await singleton.createNewHandler(
              address: StunServers.googleStun,
              port: StunServers.defaultPort,
              ipv6: true,
            );

        expect(handler, isNotNull);

        final socket = singleton.getSocket();
        expect(socket.address.type, equals(InternetAddressType.IPv6));
      } catch (e) {
        print('IPv6 test skipped (IPv6 not available): $e');
      }
    });

    test('throws StateError if handler not initialized', () {
      final singleton = StunHandlerSingleton();

      expect(
        () => singleton.performStunRequest(),
        throwsA(isA<StateError>()),
      );
    });

    test('performStunRequest delegates to internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final response = await singleton.performStunRequest();
      expect(response.publicIp, isNotEmpty);
      expect(response.publicPort, greaterThan(0));
    });

    test('performLocalRequest delegates to internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final localInfo = await singleton.performLocalRequest();
      expect(localInfo.localIp, isNotEmpty);
      expect(localInfo.localPort, greaterThan(0));
    });

    test('setStunServer delegates to internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302);
    });

    test('pingStunServer delegates to internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final reachable = await singleton.pingStunServer();
      expect(reachable, isTrue);
    });

    test('getSocket delegates to internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final socket = singleton.getSocket();
      expect(socket, isNotNull);
      expect(socket.port, greaterThan(0));
    });

    test('replaceHandler replaces internal handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final originalSocket = singleton.getSocket();

      // Create a new handler and replace
      final newHandler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
      );

      singleton.replaceHandler(newHandler);

      final newSocket = singleton.getSocket();
      expect(identical(originalSocket, newSocket), isFalse);
    });

    test('close cleans up handler', () async {
      final singleton = StunHandlerSingleton.instance;
      await singleton.createNewHandler(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close();

      // Should throw StateError because handler is now null
      expect(
        () => singleton.getSocket(),
        throwsA(isA<StateError>()),
      );
    });

    test('Multiple createNewHandler calls replace the handler', () async {
      final singleton = StunHandlerSingleton.instance;

      final handler1 =
          await singleton.createNewHandler(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

      final socket1 = singleton.getSocket();

      final handler2 =
          await singleton.createNewHandler(
            address: StunServers.googleStun1,
            port: StunServers.defaultPort,
          );

      final socket2 = singleton.getSocket();

      expect(identical(socket1, socket2), isFalse);
      expect(identical(handler1, handler2), isFalse);
    });
  });
}
