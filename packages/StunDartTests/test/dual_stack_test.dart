import 'dart:io';
import 'package:stun/stun.dart';
import 'package:test/test.dart';
import 'test_constants.dart';

void main() {
  test('Get IPv6 with longer timeout', () async {
    print('\n=== Discovering IPv6 Address ===\n');

    final ipv6Servers = ServerConfigs.ipv6Servers;

    for (final server in ipv6Servers) {
      try {
        print('Trying ${server.name} (${server.address})...');

        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv6,
          0,
          reuseAddress: true,
        );

        print('  Socket created on port ${socket.port}');

        final input = (
          address: server.address,
          port: server.port,
          socket: socket,
        );

        final handler = StunHandler(input);

        try {
          final response = await handler.performStunRequest().timeout(
            TestTimeouts.medium,
          );

          print('\n✅ SUCCESS with ${server.name}!');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('Your Public IPv6: ${response.publicIp(InternetAddressType.IPv6)}');
          print('Your Public Port: ${response.publicPort(InternetAddressType.IPv6)}');
          print('IP Version: IPv6');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

          handler.close();

          expect(
            response.publicIp(InternetAddressType.IPv6) != null,
            isTrue,
            reason: 'Should receive an IPv6 address',
          );
          expect(response.publicIp(InternetAddressType.IPv6), isNotNull);
          expect(
            response.publicIp(InternetAddressType.IPv6)!.contains(':'),
            isTrue,
            reason: 'IPv6 addresses contain colons',
          );
          return; // Success, exit test
        } catch (e) {
          print('  ❌ Failed: $e\n');
          handler.close();
        }
      } catch (e) {
        print('  ❌ Socket error: $e\n');
      }
    }

    fail('Could not get IPv6 address from any STUN server');
  }, timeout: const Timeout(TestTimeouts.extraLong));

  test(
    'Verify both IPv4 and IPv6 across multiple STUN servers',
    () async {
      print('\n=== Dual Stack Test (IPv4 + IPv6) ===\n');

      final stunServers = StunServers.googleServers;

      // Test IPv4 with multiple servers
      final ipv4Addresses = <String>[];
      for (final server in stunServers) {
        try {
          final socket4 = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            0,
          );
          final input4 = (
            address: server,
            port: StunServers.defaultPort,
            socket: socket4,
          );
          final handler4 = StunHandler(input4);

          final response4 = await handler4.performStunRequest().timeout(
            TestTimeouts.short,
          );
          ipv4Addresses.add(response4.publicIp(InternetAddressType.IPv4)!);
          print('✅ IPv4 from $server: ${response4.publicIp(InternetAddressType.IPv4)}');
          handler4.close();
        } catch (e) {
          print('❌ IPv4 failed from $server: $e');
        }
      }

      // Test IPv6 with multiple servers
      final ipv6Addresses = <String>[];
      for (final server in stunServers) {
        try {
          final socket6 = await RawDatagramSocket.bind(
            InternetAddress.anyIPv6,
            0,
          );
          final input6 = (
            address: server,
            port: StunServers.defaultPort,
            socket: socket6,
          );
          final handler6 = StunHandler(input6);

          final response6 = await handler6.performStunRequest().timeout(
            TestTimeouts.medium,
          );
          ipv6Addresses.add(response6.publicIp(InternetAddressType.IPv6)!);
          print('✅ IPv6 from $server: ${response6.publicIp(InternetAddressType.IPv6)}');
          handler6.close();
        } catch (e) {
          print('❌ IPv6 failed from $server: $e');
        }
      }

      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('IPv4 Addresses: $ipv4Addresses');
      print('IPv6 Addresses: $ipv6Addresses');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Verify we got at least one response for each
      expect(
        ipv4Addresses.isNotEmpty,
        isTrue,
        reason: 'Should get at least one IPv4 address',
      );
      expect(
        ipv6Addresses.isNotEmpty,
        isTrue,
        reason: 'Should get at least one IPv6 address',
      );

      // Verify all IPv4 addresses from different servers match
      if (ipv4Addresses.length > 1) {
        expect(
          ipv4Addresses.toSet().length,
          equals(1),
          reason: 'All STUN servers should report the same IPv4 address',
        );
      }

      // Verify all IPv6 addresses from different servers match
      if (ipv6Addresses.length > 1) {
        expect(
          ipv6Addresses.toSet().length,
          equals(1),
          reason: 'All STUN servers should report the same IPv6 address',
        );
      }
    },
    timeout: const Timeout(TestTimeouts.dualStack),
  );
}
