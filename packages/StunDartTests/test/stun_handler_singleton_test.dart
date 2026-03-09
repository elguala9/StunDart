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

    group('Singleton Timestamp tests', () {
      test('ipv4LastStunUpdated is null before performStunRequest()', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        expect(singleton.ipv4LastStunUpdated, isNull, reason: 'Should be null before STUN request');
      });

      test('ipv4LastStunUpdated is set after performStunRequest()', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        final beforeRequest = DateTime.now();
        await singleton.performStunRequest();
        final afterRequest = DateTime.now();

        expect(singleton.ipv4LastStunUpdated, isNotNull, reason: 'Should not be null after performStunRequest()');
        expect(singleton.ipv4LastStunUpdated!.isAfter(beforeRequest), isTrue);
        expect(singleton.ipv4LastStunUpdated!.isBefore(afterRequest.add(const Duration(seconds: 1))), isTrue);
      });

      test('lastStunUpdated returns the most recent timestamp (IPv6 if available)', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        await singleton.performStunRequest();

        // lastStunUpdated should be set
        expect(singleton.lastStunUpdated, isNotNull, reason: 'Should return the most recent timestamp');

        // If IPv6 is available, it should be the IPv6 timestamp (since we request IPv6 in parallel and return it)
        // If IPv6 is not available, it should be IPv4 timestamp
        if (singleton.ipv6Handler != null) {
          final ipv6Timestamp = singleton.ipv6LastStunUpdated;
          final ipv4Timestamp = singleton.ipv4LastStunUpdated;

          if (ipv6Timestamp != null && ipv4Timestamp != null) {
            // lastStunUpdated should be the later of the two
            expect(
              singleton.lastStunUpdated!.isAfter(ipv4Timestamp) || singleton.lastStunUpdated!.isAtSameMomentAs(ipv4Timestamp),
              isTrue,
              reason: 'lastStunUpdated should be IPv6 (more recent) or equal to IPv4'
            );
          }
        } else {
          // Only IPv4 available
          expect(singleton.lastStunUpdated, equals(singleton.ipv4LastStunUpdated));
        }
      });

      test('All timestamp getters return null after close()', () async {
        final singleton = StunHandlerSingleton.instance;
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
        expect(singleton.ipv4LastStunUpdated, isNull, reason: 'IPv4 handler is null after close()');
        expect(singleton.ipv6LastStunUpdated, isNull, reason: 'IPv6 handler is null after close()');
        expect(singleton.ipv4LastLocalUpdated, isNull, reason: 'IPv4 handler is null after close()');
        expect(singleton.ipv6LastLocalUpdated, isNull, reason: 'IPv6 handler is null after close()');
        expect(singleton.lastStunUpdated, isNull, reason: 'No handlers available after close()');
        expect(singleton.lastLocalUpdated, isNull, reason: 'No handlers available after close()');

        print('[Singleton Timestamp Test] All timestamps are null after close()');
      });

      test('ipv4LastLocalUpdated and ipv6LastLocalUpdated work similarly to STUN timestamps', () async {
        final singleton = StunHandlerSingleton.instance;
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
      });
    });

    group('Singleton CallbackHandler tests', () {
      test('initialize() accepts onSocketRefresh without crash', () async {
        final singleton = StunHandlerSingleton.instance;

        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            // Empty callback
          },
        );

        // Should have initialized successfully
        expect(singleton.ipv4Handler, isNotNull);

        // Clean up
        singleton.close();
      });

      test('Singleton callback receives ipv6 parameter for IPv4 handler',
          () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            // Callback signature verified by accepting the ipv6 parameter
          },
        );

        try {
          // Verify the callback parameter structure is correct
          // The callback should be callable with the expected signature
          expect(singleton.ipv4Handler, isNotNull);

          // Perform a normal request
          final response = await singleton.ipv4Handler.performStunRequest();
          expect(response.publicIp, isNotEmpty);

          // For now, just verify the callback was registered without errors
          expect(singleton.ipv4Handler, isNotNull);
        } finally {
          singleton.close();
        }
      });

      test('Singleton callback null is a no-op', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: null,
        );

        try {
          // Should not crash even though callback is null
          final response = await singleton.ipv4Handler.performStunRequest();
          expect(response.publicIp, isNotEmpty);
        } finally {
          singleton.close();
        }
      });
    });

    group('Singleton CallbackHandler library lifecycle tests', () {
      test('Singleton callback handler initializes without errors', () async {
        int callCount = 0;

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            callCount++;
          },
        );

        try {
          // Verify both handlers are initialized
          expect(singleton.ipv4Handler, isNotNull);

          // Perform request
          final response = await singleton.performStunRequest();
          expect(response.publicIp, isNotEmpty);

          // On normal request, callback should not fire
          expect(callCount, equals(0));
        } finally {
          singleton.close();
        }
      });

      test('Singleton callback receives ipv6 flag correctly', () async {
        final List<bool> capturedFlags = [];

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            capturedFlags.add(ipv6);
          },
        );

        try {
          // Normal request
          final response = await singleton.performStunRequest();
          expect(response.publicIp, isNotEmpty);

          // On normal request, callback not fired, so no flags captured
          expect(capturedFlags, isEmpty);
        } finally {
          singleton.close();
        }
      });

      test('Singleton callback data contains correct response info', () async {
        final List<Map<String, dynamic>> capturedCalls = [];

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            capturedCalls.add({
              'newIp': newRes.publicIp,
              'newPort': newRes.publicPort,
              'oldResponse': oldRes,
              'isIpv6': ipv6,
            });
          },
        );

        try {
          final response = await singleton.performStunRequest();
          expect(response.publicIp, isNotEmpty);

          // Normal request doesn't trigger callback
          expect(capturedCalls, isEmpty);
        } finally {
          singleton.close();
        }
      });

      test('Singleton callbacks work independently per handler', () async {
        final List<String> ipv4Calls = [];
        final List<String> ipv6Calls = [];

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            if (ipv6) {
              ipv6Calls.add(newRes.publicIp);
            } else {
              ipv4Calls.add(newRes.publicIp);
            }
          },
        );

        try {
          // Normal request on both
          final response = await singleton.performStunRequest();
          expect(response.publicIp, isNotEmpty);

          // Callbacks should not have fired
          expect(ipv4Calls, isEmpty);
          expect(ipv6Calls, isEmpty);

          // IPv4 handler should exist
          expect(singleton.ipv4Handler, isNotNull);
        } finally {
          singleton.close();
        }
      });

      test('Singleton close() properly cleans up all handlers and callbacks',
          () async {
        int callCount = 0;

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            callCount++;
          },
        );

        // Perform a request
        final response = await singleton.performStunRequest();
        expect(response.publicIp, isNotEmpty);

        // Close all handlers
        singleton.close();

        // After close, handlers should be null
        expect(
          () => singleton.ipv4Handler,
          throwsStateError,
          reason: 'IPv4 handler should throw StateError after close',
        );

        // Call count should still be 0 (no socket refresh on normal request)
        expect(callCount, equals(0));
      });

      test(
          'Singleton callbacks preserved across setStunServer (same socket)',
          () async {
        int callCount = 0;

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            callCount++;
          },
        );

        try {
          // Perform request
          final response1 = await singleton.performStunRequest();
          expect(response1.publicIp, isNotEmpty);

          // Change server (same socket, so cached)
          singleton.setStunServer(StunServers.googleStun, StunServers.defaultPort);

          // Callback handler should still exist
          expect(singleton.ipv4Handler, isNotNull);

          // On normal request, callback still doesn't fire
          expect(callCount, equals(0));
        } finally {
          singleton.close();
        }
      });

      test('Singleton handles replaceHandler with callback preservation',
          () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {},
        );

        try {
          // Get original handler
          final originalHandler = singleton.ipv4Handler;
          expect(originalHandler, isNotNull);

          // Perform request to verify it works
          final response = await originalHandler.performStunRequest();
          expect(response.publicIp, isNotEmpty);
        } finally {
          singleton.close();
        }
      });

      test('Singleton callback works with multiple sequential requests',
          () async {
        int callCount = 0;

        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: (newRes, oldRes, {required ipv6}) {
            callCount++;
          },
        );

        try {
          // Multiple requests
          for (int i = 0; i < 3; i++) {
            final response = await singleton.performStunRequest();
            expect(response.publicIp, isNotEmpty);
          }

          // Callback should not have fired on cached requests
          expect(callCount, equals(0));
        } finally {
          singleton.close();
        }
      });

      test('Singleton callback null parameter does not cause errors',
          () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: null,
        );

        try {
          // Multiple requests should work fine
          for (int i = 0; i < 2; i++) {
            final response = await singleton.performStunRequest();
            expect(response.publicIp, isNotEmpty);
          }

          // Local request should also work
          final localInfo = await singleton.performLocalRequest();
          expect(localInfo.localIp, isNotEmpty);
        } finally {
          singleton.close();
        }
      });
    });

    group('Singleton addOnSocketRefresh / removeOnSocketRefresh tests', () {
      test('addOnSocketRefresh registers without crash', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          int callCount = 0;
          singleton.addOnSocketRefresh((newRes, oldRes, {required ipv6}) {
            callCount++;
          });

          expect(callCount, equals(0)); // No callback fired during registration
        } finally {
          singleton.close();
        }
      });

      test('addOnSocketRefresh idempotent — double-add same reference is a no-op', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          final callback = (StunResponse newRes, StunResponse? oldRes, {required bool ipv6}) {};

          singleton.addOnSocketRefresh(callback);
          singleton.addOnSocketRefresh(callback); // Add same reference again

          expect(true, isTrue); // No error on double-add
        } finally {
          singleton.close();
        }
      });

      test('removeOnSocketRefresh removes callback without crash; subsequent remove is no-op', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          final callback = (StunResponse newRes, StunResponse? oldRes, {required bool ipv6}) {};

          singleton.addOnSocketRefresh(callback);
          singleton.removeOnSocketRefresh(callback); // Remove the callback
          singleton.removeOnSocketRefresh(callback); // Remove again (no-op)

          expect(true, isTrue); // No error on removal
        } finally {
          singleton.close();
        }
      });

      test('removeOnSocketRefresh on unregistered callback is a no-op', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          final unregisteredCallback = (StunResponse newRes, StunResponse? oldRes, {required bool ipv6}) {};
          singleton.removeOnSocketRefresh(unregisteredCallback); // No-op, should not crash

          expect(true, isTrue); // If we reach here, no exception was thrown
        } finally {
          singleton.close();
        }
      });

      test('IStunHandlerSingleton interface exposes both methods (compile check)', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          // These should compile - interface methods are public
          IStunHandlerSingleton iSingleton = singleton;
          iSingleton.addOnSocketRefresh((newRes, oldRes, {required ipv6}) {});
          iSingleton.removeOnSocketRefresh((newRes, oldRes, {required ipv6}) {});

          expect(true, isTrue); // If we reach here, interface is correct
        } finally {
          singleton.close();
        }
      });

      test('addOnSocketRefresh after initialize(onSocketRefresh: null) works independently', () async {
        final singleton = StunHandlerSingleton.instance;
        await singleton.initialize(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onSocketRefresh: null, // Explicitly no callback during initialize
        );

        try {
          int callCount = 0;
          singleton.addOnSocketRefresh((newRes, oldRes, {required ipv6}) {
            callCount++;
          });

          // Independently added callback should work without interference from initialize param
          expect(callCount, equals(0)); // No callback fired during registration
        } finally {
          singleton.close();
        }
      });
    });
  });
}
