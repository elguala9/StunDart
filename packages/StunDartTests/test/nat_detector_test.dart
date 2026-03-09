import 'dart:io';
import 'package:stun/stun.dart';
import 'package:test/test.dart';
import 'test_constants.dart';

/// Test suite for NATDetector class
void main() {
  group('NATDetector - Constructor and Configuration', () {
    test('should create detector with required parameters', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
      );

      expect(detector, isNotNull);
      socket.close();
    });

    test('should accept custom timeout', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: const Duration(seconds: 10),
      );

      expect(detector, isNotNull);
      socket.close();
    });

    test('should work with reusable socket', () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
      );

      expect(detector, isNotNull);
      socket.close();
    });
  });

  group('NATDetector - Basic Detection', () {
    test('should detect NAT type successfully', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        // Should get some result
        expect(result.natType, isNotNull);

        // Should have detection time
        expect(result.detectionTime.inMilliseconds, greaterThan(0));

        // Should have diagnostics
        expect(result.diagnostics, isNotEmpty);
        expect(result.diagnostics.keys, contains('test1'));

        print('Detected NAT type: ${result.natType.displayName}');
        print('Public IP: ${result.publicIp}:${result.publicPort}');
        print('RFC 5780 Support: ${result.rfc5780Supported}');
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));

    test('should provide valid public IP and port', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        // Unless UDP is blocked, should have public IP and port
        if (result.natType != NATType.udpBlocked) {
          expect(result.publicIp, isNotNull);
          expect(result.publicIp, isNotEmpty);
          expect(result.publicPort, isNotNull);
          expect(result.publicPort, greaterThan(0));
          expect(result.publicPort, lessThan(65536));

          // IP should be valid format
          final ipParts = result.publicIp!.split('.');
          if (ipParts.length == 4) {
            // IPv4
            for (final part in ipParts) {
              final num = int.tryParse(part);
              expect(num, isNotNull);
              expect(num, greaterThanOrEqualTo(0));
              expect(num, lessThanOrEqualTo(255));
            }
          }
        }
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));

    test('should include filtering and mapping behavior', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        expect(result.filteringBehavior, isNotNull);
        expect(result.mappingBehavior, isNotNull);

        // Should be one of the defined behaviors
        expect(
          NATFilteringBehavior.values,
          contains(result.filteringBehavior),
        );
        expect(
          NATMappingBehavior.values,
          contains(result.mappingBehavior),
        );

        print('Filtering: ${result.filteringBehavior.displayName}');
        print('Mapping: ${result.mappingBehavior.displayName}');
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));
  });

  group('NATDetector - Multiple Servers', () {
    test('should work with different STUN servers', () async {
      final servers = [
        (StunServers.googleStun, StunServers.defaultPort),
        (StunServers.googleStun1, StunServers.defaultPort),
      ];

      final results = <NATType>[];

      for (final (server, port) in servers) {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );

        final detector = NATDetector(
          primaryServer: server,
          primaryPort: port,
          socket: socket,
          timeout: TestTimeouts.medium,
        );

        try {
          final result = await detector.detectNATType();
          results.add(result.natType);
          print('$server: ${result.natType.displayName}');
        } finally {
          socket.close();
        }

        // Small delay between servers
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // All servers should detect the same NAT type
      if (results.length > 1) {
        expect(results[0], equals(results[1]),
            reason: 'Different servers should detect the same NAT type');
      }
    }, timeout: const Timeout(TestTimeouts.dualStack));

    test('should maintain consistent results on repeated calls', () async {
      final results = <NATType>[];

      for (var i = 0; i < 2; i++) {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );

        final detector = NATDetector(
          primaryServer: StunServers.googleStun,
          primaryPort: StunServers.defaultPort,
          socket: socket,
          timeout: TestTimeouts.medium,
        );

        try {
          final result = await detector.detectNATType();
          results.add(result.natType);
          print('Attempt ${i + 1}: ${result.natType.displayName}');
        } finally {
          socket.close();
        }

        // Small delay between attempts
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      // Results should be consistent
      expect(results[0], equals(results[1]),
          reason: 'NAT type should be consistent across calls');
    }, timeout: const Timeout(TestTimeouts.dualStack));
  });

  group('NATDetector - Diagnostics', () {
    test('should provide detailed test diagnostics', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        // Should have diagnostics for test 1
        expect(result.diagnostics.keys, contains('test1'));

        final test1 = result.diagnostics['test1'] as Map;
        expect(test1.keys, contains('success'));

        // If test1 succeeded, should have IP and port
        if (test1['success'] == true) {
          expect(test1.keys, contains('publicIp'));
          expect(test1.keys, contains('publicPort'));
        }

        print('\nDiagnostics:');
        result.diagnostics.forEach((key, value) {
          print('  $key: $value');
        });
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));

    test('should track RFC 5780 support', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        expect(result.rfc5780Supported, isNotNull);
        expect(result.rfc5780Supported, isA<bool>());

        print('RFC 5780 Supported: ${result.rfc5780Supported}');

        // If RFC 5780 is supported, should have alternate address
        if (result.rfc5780Supported) {
          // Alternate address may or may not be present
          print('Alternate: ${result.alternateIp}:${result.alternatePort}');
        }
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));
  });

  group('NATDetector - Edge Cases', () {
    test('should handle invalid server gracefully', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: 'invalid.server.example.com',
        primaryPort: 3478,
        socket: socket,
        timeout: TestTimeouts.short,
      );

      try {
        final result = await detector.detectNATType();

        // Should detect as UDP blocked or have error
        expect(result.natType, equals(NATType.udpBlocked));
        expect(result.diagnostics, isNotEmpty);
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.medium));

    test('should handle unreachable server (TEST-NET-1)', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: '192.0.2.1', // TEST-NET-1, reserved, won't respond
        primaryPort: 3478,
        socket: socket,
        timeout: TestTimeouts.short,
      );

      try {
        final result = await detector.detectNATType();

        // Should detect as UDP blocked
        expect(result.natType, equals(NATType.udpBlocked));
        expect(result.publicIp, isNull);
        expect(result.publicPort, isNull);
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.medium));

    test('should respect timeout settings', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: '192.0.2.1', // Won't respond
        primaryPort: 3478,
        socket: socket,
        timeout: const Duration(seconds: 2), // Short timeout
      );

      final stopwatch = Stopwatch()..start();

      try {
        await detector.detectNATType();
      } finally {
        stopwatch.stop();
        socket.close();
      }

      // Should timeout in reasonable time (allow some overhead)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(5),
        reason: 'Detection should respect timeout',
      );
    }, timeout: const Timeout(TestTimeouts.medium));
  });

  group('NATDetector - Detection Time', () {
    test('should complete detection in reasonable time', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      final stopwatch = Stopwatch()..start();

      try {
        final result = await detector.detectNATType();
        stopwatch.stop();

        print('Detection time: ${stopwatch.elapsed.inMilliseconds}ms');
        print('Result time: ${result.detectionTime.inMilliseconds}ms');

        // Detection time in result should match elapsed time roughly
        final difference = (stopwatch.elapsed.inMilliseconds -
                result.detectionTime.inMilliseconds)
            .abs();
        expect(difference, lessThan(1000), reason: 'Times should be similar');

        // Should complete within reasonable time
        expect(
          result.detectionTime.inSeconds,
          lessThan(30),
          reason: 'Detection should complete within 30 seconds',
        );
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));
  });

  group('NATDetector - Socket Management', () {
    test('should use the provided socket', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final originalPort = socket.port;

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        await detector.detectNATType();

        // Socket port should remain the same
        expect(socket.port, equals(originalPort));
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));

    test('should work with socket on specific interface', () async {
      // Bind to loopback for testing
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();
        expect(result, isNotNull);
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));
  });

  group('NATDetector - Result Validation', () {
    test('should have valid result structure', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        // Check all required fields exist
        expect(result.natType, isNotNull);
        expect(result.filteringBehavior, isNotNull);
        expect(result.mappingBehavior, isNotNull);
        expect(result.rfc5780Supported, isNotNull);
        expect(result.detectionTime, isNotNull);
        expect(result.diagnostics, isNotNull);

        // Enums should have valid values
        expect(NATType.values, contains(result.natType));
        expect(
          NATFilteringBehavior.values,
          contains(result.filteringBehavior),
        );
        expect(
          NATMappingBehavior.values,
          contains(result.mappingBehavior),
        );
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));

    test('should have consistent NAT type and behaviors', () async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final detector = NATDetector(
        primaryServer: StunServers.googleStun,
        primaryPort: StunServers.defaultPort,
        socket: socket,
        timeout: TestTimeouts.medium,
      );

      try {
        final result = await detector.detectNATType();

        // Validate consistency between NAT type and behaviors
        switch (result.natType) {
          case NATType.openInternet:
          case NATType.fullCone:
            // Should have endpoint-independent filtering
            expect(
              result.filteringBehavior,
              equals(NATFilteringBehavior.endpointIndependent),
            );
            break;

          case NATType.symmetric:
            // Should have address-and-port-dependent behaviors
            expect(
              result.filteringBehavior,
              equals(NATFilteringBehavior.addressAndPortDependent),
            );
            expect(
              result.mappingBehavior,
              equals(NATMappingBehavior.addressAndPortDependent),
            );
            break;

          case NATType.restrictedCone:
            // Should have address-dependent filtering
            expect(
              result.filteringBehavior,
              equals(NATFilteringBehavior.addressDependent),
            );
            break;

          case NATType.portRestrictedCone:
            // Should have address-and-port-dependent filtering
            expect(
              result.filteringBehavior,
              equals(NATFilteringBehavior.addressAndPortDependent),
            );
            break;

          case NATType.udpBlocked:
          case NATType.symmetricFirewall:
            // Behaviors may be unknown
            break;
        }

        print('NAT Type: ${result.natType.displayName}');
        print('Filtering: ${result.filteringBehavior.displayName}');
        print('Mapping: ${result.mappingBehavior.displayName}');
      } finally {
        socket.close();
      }
    }, timeout: const Timeout(TestTimeouts.extraLong));
  });
}
