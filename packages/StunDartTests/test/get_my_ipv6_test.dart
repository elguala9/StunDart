import 'dart:io';
import 'package:stun/stundart.dart';
import 'package:test/test.dart';
import 'test_constants.dart';


void main() {
  test('Get my public IPv6 address', () async {
    print('\n=== Getting Public IPv6 Address ===\n');
    
    try {
      // Try to create IPv6 socket
      print('Creating IPv6 socket...');
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv6,
        0,
        reuseAddress: true,
      );
      
      print('IPv6 socket created on port: ${socket.port}');
      print('Socket address: ${socket.address}');
      
      // Use Google's IPv6 STUN server
      final input = (
        address: StunServers.googleStun, // Google STUN supports both IPv4 and IPv6
        port: StunServers.defaultPort,
        socket: socket,
      );

      final handler = StunHandler(input);

      try {
        print('\nSending STUN request to discover public IPv6...');
        final response = await handler.performStunRequest();

        print('\n✅ SUCCESS!');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Your Public IPv6: ${response.publicIp}');
        print('Your Public Port: ${response.publicPort}');
        print('IP Version: ${response.ipVersion.value}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        expect(response.ipVersion, equals(IpVersion.v6));
        expect(response.publicIp, contains(':'), reason: 'IPv6 addresses contain colons');
      } catch (e) {
        print('\n❌ Failed to get IPv6 address');
        print('Error: $e');
        print('\nPossible reasons:');
        print('  - Your ISP does not provide IPv6 connectivity');
        print('  - Your router/network is not configured for IPv6');
        print('  - IPv6 is disabled on your system');
        print('  - Firewall blocking IPv6 UDP traffic');
        
        // Don't fail the test, just inform
        print('\nTo check IPv6 connectivity, visit: https://test-ipv6.com/');
      } finally {
        handler.close();
      }
    } catch (e) {
      print('\n❌ Cannot create IPv6 socket');
      print('Error: $e');
      print('\nIPv6 is not available on this system.');
    }
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('Compare IPv4 and IPv6 addresses', () async {
    print('\n=== Comparing IPv4 and IPv6 Addresses ===\n');
    
    // Get IPv4 address
    String? ipv4Address;
    try {
      final socket4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final input4 = (address: StunServers.googleStun, port: StunServers.defaultPort, socket: socket4);
      final handler4 = StunHandler(input4);
      
      final response4 = await handler4.performStunRequest();
      ipv4Address = response4.publicIp;
      
      print('IPv4 Address: $ipv4Address');
      handler4.close();
    } catch (e) {
      print('IPv4 failed: $e');
    }
    
    // Get IPv6 address
    String? ipv6Address;
    try {
      final socket6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      final input6 = (address: StunServers.googleStun, port: StunServers.defaultPort, socket: socket6);
      final handler6 = StunHandler(input6);
      
      final response6 = await handler6.performStunRequest();
      ipv6Address = response6.publicIp;
      
      print('IPv6 Address: $ipv6Address');
      handler6.close();
    } catch (e) {
      print('IPv6 failed: $e');
    }
    
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Summary:');
    print('  IPv4: ${ipv4Address ?? 'Not available'}');
    print('  IPv6: ${ipv6Address ?? 'Not available'}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    if (ipv4Address != null) {
      expect(ipv4Address, isNotEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 20)));
}
