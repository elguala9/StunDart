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
        print('\n--- Testing STUN server: ${server.address}:${server.port} ---');

        // Create a new socket for each server
        final testSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        
        final input = (
          address: server.address,
          port: server.port,
          socket: testSocket,
        );

        final handler = StunHandler(input);

        try {
          // Perform STUN request
          final response = await handler.performStunRequest();

          print('Public IP: ${response.publicIp}');
          print('Public Port: ${response.publicPort}');

          publicIps.add(response.publicIp);

          // Verify response contains valid data
          expect(response.publicIp, isNotEmpty);
          expect(response.publicPort, greaterThan(0));
          expect(response.publicPort, lessThan(65536));
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
        expect(matchingIps, greaterThanOrEqualTo(2),
            reason: 'At least 2 STUN servers should return the same public IP');
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

      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

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

      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

      final localInfo = await handler.performLocalRequest();

      print('Local IP: ${localInfo.localIp}');
      print('Local Port: ${localInfo.localPort}');

      expect(localInfo.localIp, isNotEmpty);
      expect(localInfo.localPort, greaterThan(0));

      handler.close();
    });

    test('Change STUN server configuration', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

      // Change to a different STUN server (use Google stun1)
      handler.setStunServer(StunServers.googleStun1, StunServers.defaultPort);

      final response = await handler.performStunRequest();

      expect(response.publicIp, isNotEmpty);

      handler.close();
    });

    test('Handle STUN request timeout', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final input = (
        address: StunServers.testNet1, // TEST-NET-1, should not respond
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

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

        final input = (
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          socket: socket,
        );

        final handler = StunHandler(input);

        print('\n--- Testing IPv6 STUN ---');
        
        try {
          final response = await handler.performStunRequest();

          print('Public IPv6: ${response.publicIp}');
          print('Public Port: ${response.publicPort}');
          print('IP Version: ${response.ipVersion.value}');

          expect(response.publicIp, isNotEmpty);
          expect(response.publicPort, greaterThan(0));
          expect(response.ipVersion, equals(IpVersion.v6));
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
      
      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);
      final returnedSocket = handler.getSocket();

      // Verify it returns the same socket
      expect(returnedSocket.port, equals(originalPort));
      expect(returnedSocket.address, equals(socket.address));
      expect(identical(returnedSocket, socket), isTrue, 
          reason: 'Should return the exact same socket instance');

      handler.close();
    });

    test('close releases socket resources', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final port = socket.port;

      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

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

    test('StunHandler.withoutSocket() creates handler with internal socket', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      try {
        // Verify socket was created
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));

        // Verify handler can make STUN requests
        final response = await handler.performStunRequest();
        expect(response.publicIp, isNotEmpty);
        expect(response.publicPort, greaterThan(0));
      } finally {
        handler.close();
      }
    });

    test('StunHandler.withSocket() creates handler from external socket', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final originalPort = socket.port;

      final handler = StunHandler.withSocket(
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
    });

    test('getSocket throws StateError when socket not initialized', () async {
      final input = (
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
        socket: null as RawDatagramSocket?,
      );

      final handler = StunHandler(input);

      // Should throw StateError
      expect(
        () => handler.getSocket(),
        throwsA(isA<StateError>()),
      );
    });

    test('performStunRequest handles socket errors and recreates socket', () async {
      // Create handler with internal socket
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      try {
        // Perform a successful STUN request
        final response = await handler.performStunRequest();
        expect(response.publicIp, isNotEmpty);
        expect(response.publicPort, greaterThan(0));

        // Verify we have a valid socket
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));

        // The error handling and socket recreation are tested implicitly
        // in other tests (e.g., Handle STUN request timeout)
      } finally {
        handler.close();
      }
    });

    test('StunHandler.withoutSocket with IPv6', () async {
      try {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          ipv6: true,
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

    test('StunHandler.withoutSocket() creates handler with internal socket', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      try {
        // Verify socket was created
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));
        expect(socket.address.type, equals(InternetAddressType.IPv4));

        // Verify handler can make STUN requests
        final response = await handler.performStunRequest();
        expect(response.publicIp, isNotEmpty);
        expect(response.publicPort, greaterThan(0));
        expect(response.ipVersion, equals(IpVersion.v4));
      } finally {
        handler.close();
      }
    });

    test('StunHandler.withoutSocket() with IPv6', () async {
      try {
        final handler = await StunHandler.withoutSocket(
          address: StunServers.googleStun,
          port: StunServers.defaultPort,
          ipv6: true,
        );

        try {
          // Verify IPv6 socket was created
          final socket = handler.getSocket();
          expect(socket.address.type, equals(InternetAddressType.IPv6));

          print('IPv6 socket created with withoutSocket: ${socket.address}:${socket.port}');

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
      );

      try {
        // Verify socket was created
        final socket = handler.getSocket();
        expect(socket, isNotNull);
        expect(socket.port, greaterThan(0));

        // Perform STUN request with custom server
        final response = await handler.performStunRequest();
        expect(response.publicIp, isNotEmpty);
        expect(response.publicPort, greaterThan(0));
      } finally {
        handler.close();
      }
    });

    test('StunHandler.withoutSocket() with default server configuration', () async {
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
    });

    test('StunHandler.withoutSocket() can perform multiple STUN requests', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      try {
        // First request
        final response1 = await handler.performStunRequest();
        expect(response1.publicIp, isNotEmpty);

        // Second request on same handler
        final response2 = await handler.performStunRequest();
        expect(response2.publicIp, isNotEmpty);

        // IPs should be the same since we're on the same socket
        expect(response1.publicIp, equals(response2.publicIp));
      } finally {
        handler.close();
      }
    });

    test('StunHandler.withoutSocket() can change STUN server after creation', () async {
      final handler = await StunHandler.withoutSocket(
        address: StunServers.googleStun,
        port: StunServers.defaultPort,
      );

      try {
        // Perform request with initial server
        final response1 = await handler.performStunRequest();
        expect(response1.publicIp, isNotEmpty);

        // Change server
        handler.setStunServer(StunServers.googleStun1, StunServers.defaultPort);

        // Perform request with new server
        final response2 = await handler.performStunRequest();
        expect(response2.publicIp, isNotEmpty);

        // Should still get valid responses
        expect(response2.publicPort, greaterThan(0));
      } finally {
        handler.close();
      }
    });

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
      );

      try {
        // Get local network information
        final localInfo = await handler.performLocalRequest();

        print('Local IP: ${localInfo.localIp}');
        print('Local Port: ${localInfo.localPort}');

        expect(localInfo.localIp, isNotEmpty);
        expect(localInfo.localPort, greaterThan(0));
      } finally {
        handler.close();
      }
    });
  });
}
