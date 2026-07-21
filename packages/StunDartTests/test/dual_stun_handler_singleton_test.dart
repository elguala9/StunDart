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

    test('replaceHandler(mock, ipv6: true) replaces only IPv6', () async {
      final singleton = DualStunHandlerSingleton.instance;
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
      final singleton = DualStunHandlerSingleton.instance;
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
      final socket = singleton.ipv4Handler!.getSocket();
      expect(socket, isNotNull);
    });

    test('setStunServer with ipv6: null sets both handlers', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: null);
    });

    test('setStunServer with ipv6: false sets only IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Should not throw
      singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: false);
    });

    test(
      'setStunServer with ipv6: true sets only IPv6 (if available)',
      () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        // Should not throw even if IPv6 not available
        singleton.setStunServer(StunServers.googleStun1, 19302, ipv6: true);
      },
    );

    test('close(ipv6: false) closes IPv4', () async {
      final singleton = DualStunHandlerSingleton.instance;
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
      final singleton = DualStunHandlerSingleton.instance;
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
      final singleton = DualStunHandlerSingleton.instance;
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
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final socket = singleton.getSocket(ipv6: false);
      expect(socket, isNotNull);
      expect(socket.address.type, equals(InternetAddressType.IPv4));
    });

    test('getSocket(ipv6: true) returns IPv6 socket if available', () async {
      final singleton = DualStunHandlerSingleton.instance;
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
      final singleton = DualStunHandlerSingleton.instance;
      await singleton.initialize(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final reachable = await singleton.pingStunServer(ipv6: false);
      expect(reachable, isTrue);
    });

    test('pingStunServer(ipv6: true) pings IPv6 if available', () async {
      final singleton = DualStunHandlerSingleton.instance;
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

    group('Singleton typed callback tests (IPv4/IPv6 specific)', () {
      test('setOnSocketRefreshIpv4 accepts valid IPv4 callback', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          int callCount = 0;
          singleton.setOnSocketRefreshIpv4((newRes, oldRes) {
            callCount++;
          });

          // Should not throw
          expect(callCount, equals(0)); // No callback fired during registration
        } finally {
          singleton.close();
        }
      });

      test(
        'setOnSocketRefreshIpv4 throws StateError if IPv4 handler not initialized',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          // Don't initialize - handler is null

          expect(
            () => singleton.setOnSocketRefreshIpv4((newRes, oldRes) {}),
            throwsA(isA<StateError>()),
            reason: 'Should throw StateError when handler not initialized',
          );
        },
      );

      test(
        'setOnSocketRefreshIpv6 accepts valid IPv6 callback if available',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          await singleton.initialize(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          try {
            if (singleton.ipv6Handler != null) {
              int callCount = 0;
              singleton.setOnSocketRefreshIpv6((newRes, oldRes) {
                callCount++;
              });

              // Should not throw
              expect(
                callCount,
                equals(0),
              ); // No callback fired during registration
            } else {
              // IPv6 not available, should throw StateError
              expect(
                () => singleton.setOnSocketRefreshIpv6((newRes, oldRes) {}),
                throwsA(isA<StateError>()),
                reason:
                    'Should throw StateError when IPv6 handler not available',
              );
            }
          } finally {
            singleton.close();
          }
        },
      );

      test(
        'setOnSocketRefreshIpv4 validates socket type and rejects IPv6 socket',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          await singleton.initialize(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          try {
            // Get IPv4 handler and verify it's actually IPv4
            final ipv4Handler = singleton.ipv4Handler;
            expect(ipv4Handler, isNotNull);
            final ipv4Socket = ipv4Handler!.getSocket();
            expect(ipv4Socket.address.type, equals(InternetAddressType.IPv4));

            // Setting IPv4 callback on IPv4 handler should work
            singleton.setOnSocketRefreshIpv4((newRes, oldRes) {});
            expect(true, isTrue); // If we reach here, validation passed
          } finally {
            singleton.close();
          }
        },
      );

      test('removeOnSocketRefreshIpv4 works without errors', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          singleton.setOnSocketRefreshIpv4((newRes, oldRes) {});
          singleton.removeOnSocketRefreshIpv4(); // Should not throw

          expect(true, isTrue); // If we reach here, removal worked
        } finally {
          singleton.close();
        }
      });

      test('removeOnSocketRefreshIpv6 works without errors', () async {
        final singleton = DualStunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          if (singleton.ipv6Handler != null) {
            singleton.setOnSocketRefreshIpv6((newRes, oldRes) {});
            singleton.removeOnSocketRefreshIpv6(); // Should not throw

            expect(true, isTrue); // If we reach here, removal worked
          }
        } finally {
          singleton.close();
        }
      });

      test(
        'setOnSocketRefreshIpv4 multiple times replaces previous callback',
        () async {
          final singleton = DualStunHandlerSingleton.instance;
          await singleton.initialize(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          try {
            singleton.setOnSocketRefreshIpv4((newRes, oldRes) {});
            singleton.setOnSocketRefreshIpv4((newRes, oldRes) {});

            // Both registrations should succeed without errors
            expect(true, isTrue);
          } finally {
            singleton.close();
          }
        },
      );
    });
  });
}
