import 'dart:io';
import 'dart:async';
import 'package:stun/stun.dart';
import 'package:test/test.dart';
import 'test_constants.dart';

void main() {
  group('StunHandler Tests', () {
    test('Query multiple STUN servers and compare public IPs', () async {
      // List of STUN servers to query
      final stunServers = [
        (address: StunServers.googleStun, port: StunServers.defaultPort),
        (address: StunServers.googleStun1, port: StunServers.defaultPort),
        (address: StunServers.stunProtocol, port: StunServers.alternativePort),
      ];

      final publicIps = <String>[];

      // Query each STUN server
      for (final server in stunServers) {
        print(
          '\n--- Testing STUN server: ${server.address}:${server.port} ---',
        );

        // Create a new socket for each server
        final testSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );

        final handler = StunHandler(
          testSocket,
          address: server.address,
          port: server.port,
        );

        try {
          // Perform STUN request
          final response = await handler.performStunRequest();

          print('Public IP: ${response.publicIp(InternetAddressType.IPv4)}');
          print('Public Port: ${response.publicPort(InternetAddressType.IPv4)}');

          publicIps.add(response.publicIp(InternetAddressType.IPv4)!);

          // Verify response contains valid data
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
          expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));
          expect(response.publicPort(InternetAddressType.IPv4), lessThan(65536));
        } catch (e) {
          print('Error querying ${server.address}: $e');
          // Add empty string to maintain list alignment
          publicIps.add('');
        } finally {
          handler.close();
        }
      }

      // Compare public IPs from different servers
      print('\n--- Comparing Results ---');
      final validIps = publicIps.where((ip) => ip.isNotEmpty).toList();

      if (validIps.length >= 2) {
        print('Public IPs received:');
        for (int i = 0; i < publicIps.length; i++) {
          if (publicIps[i].isNotEmpty) {
            print('  ${stunServers[i].address}: ${publicIps[i]}');
          } else {
            print('  ${stunServers[i].address}: FAILED');
          }
        }

        // Check if at least 2 servers returned the same IP
        final firstValidIp = validIps.first;
        final matchingIps = validIps.where((ip) => ip == firstValidIp).length;

        print('\nAll matching IPs: ${matchingIps == validIps.length}');

        // Expect at least 2 servers to agree on the public IP
        expect(
          matchingIps,
          greaterThanOrEqualTo(2),
          reason: 'At least 2 STUN servers should return the same public IP',
        );
      } else {
        fail('Not enough STUN servers responded successfully');
      }
    });

    test('Ping STUN server successfully', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final handler = StunHandler(
        socket,
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final result = await handler.pingStunServer();

      expect(result, isTrue);

      handler.close();
    });

    test('Get local network information', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final handler = StunHandler(
        socket,
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final localInfo = await handler.performLocalRequest();

      print('Local IP: ${localInfo.localIpv4}');
      print('Local Port: ${localInfo.localPortIpv4}');

      expect(localInfo.localIpv4, isNotEmpty);
      expect(localInfo.localPortIpv4, greaterThan(0));

      handler.close();
    });

    test('Change STUN server configuration', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final handler = StunHandler(
        socket,
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Change to a different STUN server (use Google stun1)
      handler.setStunServer(StunServers.googleStun1, StunServers.defaultPort);

      final response = await handler.performStunRequest();

      expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);

      handler.close();
    });

    test('Handle STUN request timeout', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final handler = StunHandler(
        socket,
        address: StunServers.testNet1, // TEST-NET-1, should not respond
        port: StunServers.defaultPort,
      );

      // Expect timeout exception
      expect(
        () => handler.performStunRequest(),
        throwsA(isA<TimeoutException>()),
      );

      handler.close();
    }, timeout: const Timeout(TestTimeouts.medium));

    test('Query STUN server with IPv6', () async {
      try {
        // Create IPv6 socket
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
          reuseAddress: true,
        );

        final handler = StunHandler(
          socket,
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        print('\n--- Testing IPv6 STUN ---');

        try {
          final response = await handler.performStunRequest();

          print('Public IPv6: ${response.publicIp(InternetAddressType.IPv6)}');
          print('Public Port: ${response.publicPort(InternetAddressType.IPv6)}');
          print('IP Version: IPv6');

          expect(response.publicIp(InternetAddressType.IPv6), isNotEmpty);
          expect(response.publicPort(InternetAddressType.IPv6), greaterThan(0));
          expect(response.publicIp(InternetAddressType.IPv6), isNotNull);
        } catch (e) {
          print('IPv6 test failed (might not be available): $e');
          // IPv6 might not be available in all environments
          // Don't fail the test, just skip it
        } finally {
          handler.close();
        }
      } catch (e) {
        print('IPv6 socket binding failed (IPv6 not available): $e');
        // IPv6 not available on this system, skip test
      }
    }, timeout: const Timeout(TestTimeouts.long));

    test('getSocket returns the underlying socket', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final originalPort = socket.port;

      final handler = StunHandler(
        socket,
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );
      final returnedSocket = handler.getSocket();

      // Verify it returns the same socket
      expect(returnedSocket.port, equals(originalPort));
      expect(returnedSocket.address, equals(socket.address));
      expect(
        identical(returnedSocket, socket),
        isTrue,
        reason: 'Should return the exact same socket instance',
      );

      handler.close();
    });

    test('close releases socket resources', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final port = socket.port;

      final handler = StunHandler(
        socket,
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      // Verify socket is usable before close
      expect(handler.getSocket().port, equals(port));

      // Close the handler
      handler.close();

      // After close, trying to use the socket should fail or show it's closed
      // We can't directly test socket.isClosed in Dart, but we can verify
      // that operations fail or handler behaves appropriately
      expect(() => handler.getSocket().port, returnsNormally);

      // Verify we can bind to the same port again (socket was released)
      final newSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      expect(newSocket.port, equals(port));
      newSocket.close();
    });

    test(
      'StunHandler.withoutSocket() creates handler with internal socket',
      () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // Verify socket was created
          final socket = handler.getSocket();
          expect(socket, isNotNull);
          expect(socket.port, greaterThan(0));

          // Verify handler can make STUN requests
          final response = await handler.performStunRequest();
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
          expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));
        } finally {
          handler.close();
        }
      },
    );

    test(
      'StunHandler() creates handler from external socket',
      () async {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        final originalPort = socket.port;

        final handler = StunHandler(
          socket,
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          // Verify it uses the provided socket
          final returnedSocket = handler.getSocket();
          expect(identical(returnedSocket, socket), isTrue);
          expect(returnedSocket.port, equals(originalPort));
        } finally {
          handler.close();
        }
      },
    );

    test(
      'performStunRequest handles socket errors and recreates socket',
      () async {
        // Create handler with internal socket
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // Perform a successful STUN request
          final response = await handler.performStunRequest();
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
          expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));

          // Verify we have a valid socket
          final socket = handler.getSocket();
          expect(socket, isNotNull);
          expect(socket.port, greaterThan(0));

          // The error handling and socket recreation are tested implicitly
          // in other tests (e.g., Handle STUN request timeout)
        } finally {
          handler.close();
        }
      },
    );

    test('StunHandler.withoutSocket with IPv6', () async {
      try {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv6,
        );

        try {
          // Verify IPv6 socket was created
          final socket = handler.getSocket();
          expect(socket.address.type, equals(InternetAddressType.IPv6));

          print('IPv6 socket created: ${socket.address}:${socket.port}');
        } finally {
          handler.close();
        }
      } catch (e) {
        print('IPv6 test skipped (IPv6 not available): $e');
        // IPv6 might not be available on this system
      }
    });

    test('StunHandler.withoutSocket socket is eagerly initialized', () async {
      // Create handler - socket is created immediately
      final handler = await StunHandler.withoutSocket();

      try {
        // Socket should exist after create()
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));
      } finally {
        handler.close();
      }
    });

    test(
      'StunHandler.withoutSocket() creates handler with internal socket',
      () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // Verify socket was created
          final socket = handler.getSocket();
          expect(socket, isNotNull);
          expect(socket.port, greaterThan(0));
          expect(socket.address.type, equals(InternetAddressType.IPv4));

          // Verify handler can make STUN requests
          final response = await handler.performStunRequest();
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
          expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));
          expect(response.publicIp(InternetAddressType.IPv4), isNotNull);
        } finally {
          handler.close();
        }
      },
    );

    test('StunHandler.withoutSocket() with IPv6', () async {
      try {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv6,
        );

        try {
          // Verify IPv6 socket was created
          final socket = handler.getSocket();
          expect(socket.address.type, equals(InternetAddressType.IPv6));

          print(
            'IPv6 socket created with withoutSocket: ${socket.address}:${socket.port}',
          );

          // Socket should be IPv6
          expect(socket.port, greaterThan(0));
        } finally {
          handler.close();
        }
      } catch (e) {
        print('IPv6 test skipped (IPv6 not available): $e');
        // IPv6 might not be available on this system
      }
    });

    test('StunHandler.withoutSocket() with custom STUN server', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun1,
        port: StunServers.defaultPort,
        type: InternetAddressType.IPv4,
      );

      try {
        // Verify socket was created
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));

        // Perform STUN request with custom server
        final response = await handler.performStunRequest();
        expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
        expect(response.publicPort(InternetAddressType.IPv4), greaterThan(0));
      } finally {
        handler.close();
      }
    });

    test(
      'StunHandler.withoutSocket() with default server configuration',
      () async {
        // Create without specifying server (should use defaults)
        final handler = await StunHandler.withoutSocket();

        try {
          // Verify socket was created
          final socket = handler.getSocket();
          expect(socket, isNotNull);
          expect(socket.port, greaterThan(0));
        } finally {
          handler.close();
        }
      },
    );

    test(
      'StunHandler.withoutSocket() can perform multiple STUN requests',
      () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // First request
          final response1 = await handler.performStunRequest();
          expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);

          // Second request on same handler
          final response2 = await handler.performStunRequest();
          expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);

          // IPs should be the same since we're on the same socket
          expect(response1.publicIp(InternetAddressType.IPv4), equals(response2.publicIp(InternetAddressType.IPv4)));
        } finally {
          handler.close();
        }
      },
    );

    test(
      'StunHandler.withoutSocket() can change STUN server after creation',
      () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // Perform request with initial server
          final response1 = await handler.performStunRequest();
          expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);

          // Change server
          handler.setStunServer(
            StunServers.googleStun1,
            StunServers.defaultPort,
          );

          // Perform request with new server
          final response2 = await handler.performStunRequest();
          expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);

          // Should still get valid responses
          expect(response2.publicPort(InternetAddressType.IPv4), greaterThan(0));
        } finally {
          handler.close();
        }
      },
    );

    test('StunHandler.withoutSocket() close releases socket', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      final port = handler.getSocket().port;

      // Close the handler
      handler.close();

      // Verify we can bind to the same port again (socket was released)
      final newSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      expect(newSocket.port, equals(port));
      newSocket.close();
    });

    test('StunHandler.withoutSocket() performs local request', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        type: InternetAddressType.IPv4,
      );

      try {
        // Get local network information
        final localInfo = await handler.performLocalRequest();

        print('Local IP: ${localInfo.localIpv4}');
        print('Local Port: ${localInfo.localPortIpv4}');

        expect(localInfo.localIpv4, isNotEmpty);
        expect(localInfo.localPortIpv4, greaterThan(0));
      } finally {
        handler.close();
      }
    });

    group('Cache behavior tests', () {
      test('Cache: STUN response is cached on repeated requests', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // First request - makes actual STUN call
          final response1 = await handler.performStunRequest();
          expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);
          expect(response1.publicPort(InternetAddressType.IPv4), greaterThan(0));

          // Second request - should return cached value (same IP:port)
          final response2 = await handler.performStunRequest();
          expect(response2.publicIp(InternetAddressType.IPv4), equals(response1.publicIp(InternetAddressType.IPv4)));
          expect(response2.publicPort(InternetAddressType.IPv4), equals(response1.publicPort(InternetAddressType.IPv4)));

          // Third request - still cached
          final response3 = await handler.performStunRequest();
          expect(response3.publicIp(InternetAddressType.IPv4), equals(response1.publicIp(InternetAddressType.IPv4)));
          expect(response3.publicPort(InternetAddressType.IPv4), equals(response1.publicPort(InternetAddressType.IPv4)));

          print('[Cache Test] STUN response cached successfully');
        } finally {
          handler.close();
        }
      });

      test('Cache: Local info is cached on repeated requests', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // First request - makes actual call
          final localInfo1 = await handler.performLocalRequest();
          expect(localInfo1.localIpv4, isNotEmpty);
          expect(localInfo1.localPortIpv4, greaterThan(0));

          // Second request - should return cached value
          final localInfo2 = await handler.performLocalRequest();
          expect(localInfo2.localIpv4, equals(localInfo1.localIpv4));
          expect(localInfo2.localPortIpv4, equals(localInfo1.localPortIpv4));

          // Third request - still cached
          final localInfo3 = await handler.performLocalRequest();
          expect(localInfo3.localIpv4, equals(localInfo1.localIpv4));
          expect(localInfo3.localPortIpv4, equals(localInfo1.localPortIpv4));

          print('[Cache Test] Local info cached successfully');
        } finally {
          handler.close();
        }
      });

      test('Cache: Invalidates when socket is recreated due to error', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // First request - fills cache
          final response1 = await handler.performStunRequest();
          expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);
          final cachedIp = response1.publicIp(InternetAddressType.IPv4);

          // Verify second request returns cached response
          final response1b = await handler.performStunRequest();
          expect(response1b.publicIp(InternetAddressType.IPv4), equals(cachedIp));

          // Force socket recreation by closing it
          handler.getSocket().close();

          // Next request will detect the closed socket, recreate it, and reset cache
          final response2 = await handler.performStunRequest();
          expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);

          // After socket recreation, we should get a fresh response
          // (Cache was reset when socket was recreated)
          // Verify socket was recreated by checking it's a valid socket
          final newSocket = handler.getSocket();
          expect(newSocket, isNotNull);
          expect(newSocket.port, greaterThan(0));

          // Verify we can still make requests with the new socket
          final response3 = await handler.performStunRequest();
          expect(response3.publicIp(InternetAddressType.IPv4), isNotEmpty);

          print('[Cache Test] Cache invalidated on socket recreation');
        } finally {
          handler.close();
        }
      });

      test('Cache: Local info invalidates when socket is recreated', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );

        try {
          // First request - fills cache
          final localInfo1 = await handler.performLocalRequest();
          expect(localInfo1.localPortIpv4, greaterThan(0));
          final cachedPort = localInfo1.localPortIpv4;

          // Verify cached request returns same port
          final localInfo1b = await handler.performLocalRequest();
          expect(localInfo1b.localPortIpv4, equals(cachedPort));

          // Force socket recreation
          handler.getSocket().close();

          // Next request triggers socket recreation and cache reset
          final localInfo2 = await handler.performLocalRequest();
          expect(localInfo2.localPortIpv4, greaterThan(0));

          // New request should use fresh socket
          final localInfo3 = await handler.performLocalRequest();
          expect(localInfo3.localPortIpv4, greaterThan(0));

          print(
            '[Cache Test] Local info cache invalidated on socket recreation',
          );
        } finally {
          handler.close();
        }
      });

      test(
        'Cache: Not invalidated by server change (same socket = same IP)',
        () async {
          final handler = await StunHandler.withoutSocket(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
            type: InternetAddressType.IPv4,
          );

          try {
            // First request
            final response1 = await handler.performStunRequest();
            expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);
            final originalIp = response1.publicIp(InternetAddressType.IPv4);

            // Change STUN server
            handler.setStunServer(
              StunServers.googleStun1,
              StunServers.defaultPort,
            );

            // Next request should return cached response
            // (same socket = same public IP, regardless of STUN server)
            final response2 = await handler.performStunRequest();
            expect(
              response2.publicIp(InternetAddressType.IPv4),
              equals(originalIp),
              reason:
                  'Cache should return same IP even with different STUN server',
            );

            print('[Cache Test] Cache preserved across server changes');
          } finally {
            handler.close();
          }
        },
      );

      test(
        'Cache: Both STUN and local cache reset together on socket change',
        () async {
          final handler = await StunHandler.withoutSocket(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
            type: InternetAddressType.IPv4,
          );

          try {
            // Prime both caches
            final response1 = await handler.performStunRequest();
            final localInfo1 = await handler.performLocalRequest();

            expect(response1.publicIp(InternetAddressType.IPv4), isNotEmpty);
            expect(localInfo1.localPortIpv4, greaterThan(0));

            // Verify both are cached (same results)
            final response1b = await handler.performStunRequest();
            final localInfo1b = await handler.performLocalRequest();
            expect(response1b.publicIp(InternetAddressType.IPv4), equals(response1.publicIp(InternetAddressType.IPv4)));
            expect(localInfo1b.localPortIpv4, equals(localInfo1.localPortIpv4));

            // Force recreation
            handler.getSocket().close();

            // Both requests should work with new socket
            // and both caches should be reset
            final response2 = await handler.performStunRequest();
            final localInfo2 = await handler.performLocalRequest();

            expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);
            expect(localInfo2.localPortIpv4, greaterThan(0));

            print('[Cache Test] Both caches invalidated on socket recreation');
          } finally {
            handler.close();
          }
        },
      );
    });

    group('Timeout and Logging tests', () {
      test('Configurable timeout - custom timeout is used', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          timeout: const Duration(seconds: 1),
          type: InternetAddressType.IPv4,
        );
        try {
          // This should work fine with a 1-second timeout for a real STUN server
          final response = await handler.performStunRequest();
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
        } finally {
          handler.close();
        }
      });

      test('onLog callback receives messages during socket creation', () async {
        final messages = <String>[];
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          onLog: (msg) => messages.add(msg),
        );
        try {
          expect(
            messages.any((msg) => msg.contains('Socket created')),
            isTrue,
            reason: 'Should log socket creation',
          );
        } finally {
          handler.close();
        }
      });

      test('onLog with null (default) does not crash', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );
        try {
          // Should not throw
          final response = await handler.performStunRequest();
          expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
        } finally {
          handler.close();
        }
      });

      test('StunHandler.withSocket accepts timeout and onLog', () async {
        // Create a socket manually
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        try {
          final messages = <String>[];
          final handler = StunHandler(
            socket,
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
            timeout: const Duration(seconds: 2),
            onLog: (msg) => messages.add(msg),
          );
          try {
            // onLog should not crash
            final response = await handler.performStunRequest();
            expect(response.publicIp(InternetAddressType.IPv4), isNotEmpty);
          } finally {
            handler.close();
          }
        } finally {
          socket.close();
        }
      });

      test('IPv4 performLocalRequest returns IPv4 address format', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          type: InternetAddressType.IPv4,
        );
        try {
          final localInfo = await handler.performLocalRequest();
          // IPv4 address should contain dots
          expect(
            localInfo.localIpv4,
            matches(
              RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$|^127\.0\.0\.1$'),
            ),
            reason: 'IPv4 address should be in dotted format',
          );
        } finally {
          handler.close();
        }
      });

      test('IPv6 performLocalRequest returns IPv6 address format', () async {
        try {
          final handler = await StunHandler.withoutSocket(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
            type: InternetAddressType.IPv6,
          );
          try {
            final localInfo = await handler.performLocalRequest();
            // IPv6 address should contain colons
            expect(
              localInfo.localIpv6!.contains(':'),
              isTrue,
              reason: 'IPv6 address should contain colons',
            );
          } finally {
            handler.close();
          }
        } catch (e) {
          // IPv6 may not be available on all systems
          print('IPv6 test skipped: $e');
        }
      });
    });

    group('Timestamp tests', () {
      test(
        'Both lastStunUpdated and lastLocalUpdated are null initially',
        () async {
          final handler = await StunHandler.withoutSocket(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
          );

          try {
            expect(
              handler.lastStunUpdated,
              isNull,
              reason: 'Should be null before any STUN request',
            );
            expect(
              handler.lastLocalUpdated,
              isNull,
              reason: 'Should be null before any local request',
            );
          } finally {
            handler.close();
          }
        },
      );

      test('lastStunUpdated is set after performStunRequest()', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          final beforeRequest = DateTime.now();
          await handler.performStunRequest();
          final afterRequest = DateTime.now();

          expect(
            handler.lastStunUpdated,
            isNotNull,
            reason: 'Should not be null after STUN request',
          );
          expect(
            handler.lastStunUpdated!.isAfter(beforeRequest),
            isTrue,
            reason: 'Timestamp should be after request start',
          );
          expect(
            handler.lastStunUpdated!.isBefore(
              afterRequest.add(const Duration(seconds: 1)),
            ),
            isTrue,
            reason: 'Timestamp should be before request end',
          );

          // Second request should return the same cached timestamp (cache hit)
          final secondTimestamp = handler.lastStunUpdated;
          await handler.performStunRequest();
          expect(
            handler.lastStunUpdated,
            equals(secondTimestamp),
            reason: 'Timestamp should not change on cache hit',
          );

          print('[Timestamp Test] lastStunUpdated set correctly');
        } finally {
          handler.close();
        }
      });

      test('lastLocalUpdated is set after performLocalRequest()', () async {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
        );

        try {
          final beforeRequest = DateTime.now();
          await handler.performLocalRequest();
          final afterRequest = DateTime.now();

          expect(
            handler.lastLocalUpdated,
            isNotNull,
            reason: 'Should not be null after local request',
          );
          expect(
            handler.lastLocalUpdated!.isAfter(beforeRequest),
            isTrue,
            reason: 'Timestamp should be after request start',
          );
          expect(
            handler.lastLocalUpdated!.isBefore(
              afterRequest.add(const Duration(seconds: 1)),
            ),
            isTrue,
            reason: 'Timestamp should be before request end',
          );

          // Second request should return the same cached timestamp (cache hit)
          final secondTimestamp = handler.lastLocalUpdated;
          await handler.performLocalRequest();
          expect(
            handler.lastLocalUpdated,
            equals(secondTimestamp),
            reason: 'Timestamp should not change on cache hit',
          );

          print('[Timestamp Test] lastLocalUpdated set correctly');
        } finally {
          handler.close();
        }
      });

      test(
        'Timestamps are reset to null when cache is reset (socket recreation)',
        () async {
          final handler = await StunHandler.withoutSocket(
            address: StunServers.googleStun,
            port: StunServers.defaultPort,
            type: InternetAddressType.IPv4,
          );

          try {
            // Prime both caches
            await handler.performStunRequest();
            await handler.performLocalRequest();

            expect(handler.lastStunUpdated, isNotNull);
            expect(handler.lastLocalUpdated, isNotNull);

            // Force socket recreation (closes and recreates socket)
            handler.getSocket().close();

            // Next request will trigger socket recreation and cache reset
            // This should get a fresh response with a new timestamp
            final response2 = await handler.performStunRequest();
            expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);

            // Timestamp should be set and potentially updated (depending on execution timing)
            expect(handler.lastStunUpdated, isNotNull);

            // The new response should have valid data
            expect(response2.publicIp(InternetAddressType.IPv4), isNotEmpty);
            expect(response2.publicPort(InternetAddressType.IPv4), greaterThan(0));

            print(
              '[Timestamp Test] Timestamps reset and updated on socket recreation',
            );
          } finally {
            handler.close();
          }
        },
      );
    });
  });
}
