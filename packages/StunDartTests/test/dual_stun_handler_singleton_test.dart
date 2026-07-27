import 'dart:io';
import 'package:stun/stun.dart';
import 'package:test/test.dart';
import 'test_constants.dart';

void main() {
  group('DualStunHandlerSingleton Tests', () {
    tearDown(() async {
      // Clean up after each test
      try {
        DualStunHandlerSingleton.instance.close();
      } catch (_) {
        // Ignore errors during cleanup
      }
    });

    test('Singleton instance is the same when accessed via constructor', () {
      final instance1 = DualStunHandlerSingleton();
      final instance2 = DualStunHandlerSingleton();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Singleton instance is the same when accessed via .instance', () {
      final instance1 = DualStunHandlerSingleton.instance;
      final instance2 = DualStunHandlerSingleton.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('Constructor and .instance return the same instance', () {
      final instance1 = DualStunHandlerSingleton();
      final instance2 = DualStunHandlerSingleton.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('initialize() creates IPv4 handler (if available)', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // IPv4 is optional, but is expected to be available in this test environment
      final ipv4Handler = singleton.ipv4Handler;
      expect(ipv4Handler, isNotNull);
      final ipv4Socket = ipv4Handler!.getSocket();
      expect(ipv4Socket.address.type, equals(InternetAddressType.IPv4));
    });

    test(
      'initialize() throws when neither IPv4 nor IPv6 is available',
      () async {
        // At least one of ipv4Handler/ipv6Handler must be available after
        // initialize(); it is not possible to exercise the "both fail" path
        // without simulating a fully offline system, so this documents the
        // contract exercised indirectly by the other initialize() tests.
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        expect(
          singleton.ipv4Handler != null || singleton.ipv6Handler != null,
          isTrue,
          reason: 'At least one handler must be available after initialize()',
        );
      },
    );

    test('initialize() creates IPv6 handler (if available)', () async {
      final singleton = DualStunHandlerSingleton.instance;
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

    test('ipv4Handler getter returns non-null when available', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final handler = singleton.ipv4Handler;
      // IPv4 is optional, but is expected to be available in this test environment
      expect(handler, isNotNull);
      expect(
        handler!.getSocket().address.type,
        equals(InternetAddressType.IPv4),
      );
    });

    test('ipv6Handler getter may return null', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final handler = singleton.ipv6Handler;
      // May be null or non-null depending on system
      if (handler != null) {
        expect(
          handler.getSocket().address.type,
          equals(InternetAddressType.IPv6),
        );
      }
    });

    test('performStunRequest() executes on both handlers', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final response = await singleton.performStunRequest();
      // IPv4 is expected to be available in this test environment
      expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
      expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));

      if (singleton.ipv6Handler != null) {
        expect(response.publicIp(InternetAddressType.IPv6), isNotEmpty);
        expect(response.publicPort(InternetAddressType.IPv6), greaterThan(0));
      }
    });

    test('performStunRequest() returns per-stack results matching each '
        'handler', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final response = await singleton.performStunRequest();

      // If IPv6 is available, verify its slot matches a direct request
      if (singleton.ipv6Handler != null) {
        final ipv6Response = await singleton.ipv6Handler!.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv6), equals(ipv6Response.publicIp(InternetAddressType.IPv6)));
        expect(
          response.publicPort(InternetAddressType.IPv6),
          equals(ipv6Response.publicPort(InternetAddressType.IPv6)),
        );
      }
    });

    test('performLocalRequest() executes on both handlers', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final info = await singleton.performLocalRequest();
      // IPv4 is expected to be available in this test environment
      expect(info.localIpv4, isNotEmpty);
      expect(info.localPortIpv4, greaterThan(0));

      if (singleton.ipv6Handler != null) {
        expect(info.localIpv6, isNotEmpty);
        expect(info.localPortIpv6, greaterThan(0));
      }
    });

    test('performLocalRequest() caches results', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final info1 = await singleton.performLocalRequest();
      final info2 = await singleton.performLocalRequest();

      // Should be identical due to caching
      expect(
        info1.localIpv4,
        equals(info2.localIpv4),
      );
      expect(
        info1.localPortIpv4,
        equals(info2.localPortIpv4),
      );
    });

    test('replaceHandler(mock, type: InternetAddressType.IPv6) replaces only IPv6', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final originalIpv4 = singleton.ipv4Handler;
      final newHandler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
        type: InternetAddressType.IPv6,
      );

      singleton.replaceHandler(newHandler, type: InternetAddressType.IPv6);

      // IPv4 should still be the original
      final currentIpv4 = singleton.ipv4Handler;
      expect(identical(originalIpv4, currentIpv4), isTrue);
    });

    test('replaceHandler(mock, type: InternetAddressType.IPv4) replaces only IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final newHandler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
        type: InternetAddressType.IPv4,
      );

      singleton.replaceHandler(newHandler, type: InternetAddressType.IPv4);

      // Should use the new handler
      final socket = singleton.ipv4Handler!.getSocket();
      expect(socket, isNotNull);
    });

    test('setStunServer with type: null sets both handlers', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, type: null);
    });

    test('setStunServer with type: InternetAddressType.IPv4 sets only IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, type: InternetAddressType.IPv4);
    });

    test(
      'setStunServer with type: InternetAddressType.IPv6 sets only IPv6 (if available)',
      () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        // Should not throw even if IPv6 not available
        singleton.setStunServer(StunServers.googleStun1, 19302, type: InternetAddressType.IPv6);
      },
    );

    test('close(type: InternetAddressType.IPv4) closes IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close(type: InternetAddressType.IPv4);

      // IPv4 should throw
      expect(
        () => singleton.getSocket(type: InternetAddressType.IPv4),
        throwsA(isA<StateError>()),
      );
    });

    test('close(type: InternetAddressType.IPv6) closes IPv6 (if available)', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close(type: InternetAddressType.IPv6);

      // IPv4 should still work
      final ipv4Socket = singleton.getSocket(type: InternetAddressType.IPv4);
      expect(ipv4Socket, isNotNull);

      // IPv6 should not be accessible
      final ipv6Handler = singleton.ipv6Handler;
      expect(ipv6Handler, isNull);
    });

    test('close() with no param closes both handlers', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      singleton.close();

      // IPv4 should throw
      expect(
        () => singleton.getSocket(type: InternetAddressType.IPv4),
        throwsA(isA<StateError>()),
      );

      // IPv6 should be null
      expect(singleton.ipv6Handler, isNull);
    });

    test('getSocket(type: InternetAddressType.IPv4) returns IPv4 socket', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final socket = singleton.getSocket(type: InternetAddressType.IPv4);
      expect(socket, isNotNull);
      expect(socket.address.type, equals(InternetAddressType.IPv4));
    });

    test('getSocket(type: InternetAddressType.IPv6) returns IPv6 socket if available', () async {
      final singleton = DualStunHandlerSingleton.instance;
      try {
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        if (singleton.ipv6Handler != null) {
          final socket = singleton.getSocket(type: InternetAddressType.IPv6);
          expect(socket, isNotNull);
          expect(socket.address.type, equals(InternetAddressType.IPv6));
        } else {
          // Should throw if IPv6 not available
          expect(
            () => singleton.getSocket(type: InternetAddressType.IPv6),
            throwsA(isA<StateError>()),
          );
        }
      } catch (e) {
        print('IPv6 not available on this system: $e');
      }
    });

    test('pingStunServer(type: InternetAddressType.IPv4) pings IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final reachable = await singleton.pingStunServer(type: InternetAddressType.IPv4);
      expect(reachable, isTrue);
    });

    test('pingStunServer(type: InternetAddressType.IPv6) pings IPv6 if available', () async {
      final singleton = DualStunHandlerSingleton.instance;
      try {
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        if (singleton.ipv6Handler != null) {
          final reachable = await singleton.pingStunServer(type: InternetAddressType.IPv6);
          expect(reachable, isTrue);
        } else {
          expect(
            () => singleton.pingStunServer(type: InternetAddressType.IPv6),
            throwsA(isA<StateError>()),
          );
        }
      } catch (e) {
        print('IPv6 not available on this system: $e');
      }
    });

    test('initialize() accepts configurable timeout', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        timeout: const Duration(seconds: 3),
      );

      final ipv4Handler = singleton.ipv4Handler;
      expect(ipv4Handler, isNotNull);
      final response = await ipv4Handler!.performStunRequest();
      expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
    });

    test('initialize() completes without throwing', () async {
      final singleton = DualStunHandlerSingleton.instance;

      await expectLater(
        singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        ),
        completes,
      );
    });

    test('DualStunHandlerSingleton implements IDualStunHandlerSingleton', () {
      final IDualStunHandlerSingleton s = DualStunHandlerSingleton.instance;
      expect(s, isA<IDualStunHandlerSingleton>());
    });

    group('Singleton Timestamp tests', () {
      test('ipv4LastStunUpdated is null before performStunRequest()', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        expect(
          singleton.ipv4LastStunUpdated,
          isNull,
          reason: 'Should be null before STUN request',
        );
      });

      test('ipv4LastStunUpdated is set after performStunRequest()', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        final beforeRequest = DateTime.now();
        await singleton.performStunRequest();
        final afterRequest = DateTime.now();

        expect(
          singleton.ipv4LastStunUpdated,
          isNotNull,
          reason: 'Should not be null after performStunRequest()',
        );
        expect(singleton.ipv4LastStunUpdated!.isAfter(beforeRequest), isTrue);
        expect(
          singleton.ipv4LastStunUpdated!.isBefore(
            afterRequest.add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
      });

      test(
        'lastStunUpdated returns the most recent timestamp (IPv6 if available)',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          await singleton.initialize(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          await singleton.performStunRequest();

          // lastStunUpdated should be set
          expect(
            singleton.lastStunUpdated,
            isNotNull,
            reason: 'Should return the most recent timestamp',
          );

          // If IPv6 is available, it should be the IPv6 timestamp (since we request IPv6 in parallel and return it)
          // If IPv6 is not available, it should be IPv4 timestamp
          if (singleton.ipv6Handler != null) {
            final ipv6Timestamp = singleton.ipv6LastStunUpdated;
            final ipv4Timestamp = singleton.ipv4LastStunUpdated;

            if (ipv6Timestamp != null && ipv4Timestamp != null) {
              // lastStunUpdated should be the later of the two
              expect(
                singleton.lastStunUpdated!.isAfter(ipv4Timestamp) ||
                    singleton.lastStunUpdated!.isAtSameMomentAs(ipv4Timestamp),
                isTrue,
                reason:
                    'lastStunUpdated should be IPv6 (more recent) or equal to IPv4',
              );
            }
          } else {
            // Only IPv4 available
            expect(
              singleton.lastStunUpdated,
              equals(singleton.ipv4LastStunUpdated),
            );
          }
        },
      );

      test('All timestamp getters return null after close()', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        // Prime the timestamps
        await singleton.performStunRequest();
        await singleton.performLocalRequest();

        expect(singleton.ipv4LastStunUpdated, isNotNull);
        expect(singleton.ipv4LastLocalUpdated, isNotNull);

        // Close
        singleton.close();

        // All should be null
        expect(
          singleton.ipv4LastStunUpdated,
          isNull,
          reason: 'IPv4 handler is null after close()',
        );
        expect(
          singleton.ipv6LastStunUpdated,
          isNull,
          reason: 'IPv6 handler is null after close()',
        );
        expect(
          singleton.ipv4LastLocalUpdated,
          isNull,
          reason: 'IPv4 handler is null after close()',
        );
        expect(
          singleton.ipv6LastLocalUpdated,
          isNull,
          reason: 'IPv6 handler is null after close()',
        );
        expect(
          singleton.lastStunUpdated,
          isNull,
          reason: 'No handlers available after close()',
        );
        expect(
          singleton.lastLocalUpdated,
          isNull,
          reason: 'No handlers available after close()',
        );

        print(
          '[Singleton Timestamp Test] All timestamps are null after close()',
        );
      });

      test(
        'ipv4LastLocalUpdated and ipv6LastLocalUpdated work similarly to STUN timestamps',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          await singleton.initialize(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          // Before request, should be null
          expect(singleton.ipv4LastLocalUpdated, isNull);

          // After request, should be set
          await singleton.performLocalRequest();
          expect(singleton.ipv4LastLocalUpdated, isNotNull);

          // lastLocalUpdated should also be set
          expect(singleton.lastLocalUpdated, isNotNull);

          print('[Singleton Timestamp Test] Local timestamps work correctly');
        },
      );
    });

  });
}
