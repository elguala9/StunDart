import 'dart:io';
import 'package:stundart/stundart.dart';
import 'package:test/test.dart';


void main() {
  test('Get IPv6 with longer timeout', () async {
    print('\n=== Discovering IPv6 Address ===\n');
    
    final ipv6Servers = [
      (name: 'Google STUN', address: 'stun.l.google.com', port: 19302),
      (name: 'Google STUN 1', address: 'stun1.l.google.com', port: 19302),
      (name: 'Google STUN 2', address: 'stun2.l.google.com', port: 19302),
    ];
    
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
          // Increase timeout to 10 seconds
          final response = await handler.performStunRequest()
              .timeout(const Duration(seconds: 10));

          print('\n✅ SUCCESS with ${server.name}!');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('Your Public IPv6: ${response.publicIp}');
          print('Your Public Port: ${response.publicPort}');
          print('IP Version: ${response.ipVersion.value}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

          handler.close();
          
          expect(response.publicIp, equals('2001:b07:a3f:3f82:4a2:5548:c911:7969'));
          expect(response.ipVersion, equals(IpVersion.v6));
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
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('Verify both IPv4 and IPv6', () async {
    print('\n=== Dual Stack Test (IPv4 + IPv6) ===\n');
    
    // Test IPv4
    final socket4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final input4 = (address: 'stun.l.google.com', port: 19302, socket: socket4);
    final handler4 = StunHandler(input4);
    
    final response4 = await handler4.performStunRequest();
    print('✅ IPv4: ${response4.publicIp}');
    handler4.close();
    
    // Test IPv6
    final socket6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
    final input6 = (address: 'stun.l.google.com', port: 19302, socket: socket6);
    final handler6 = StunHandler(input6);
    
    final response6 = await handler6.performStunRequest()
        .timeout(const Duration(seconds: 10));
    print('✅ IPv6: ${response6.publicIp}');
    handler6.close();
    
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Your Public Addresses:');
    print('  IPv4: ${response4.publicIp}');
    print('  IPv6: ${response6.publicIp}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    expect(response4.publicIp, equals('93.57.252.90'));
    expect(response6.publicIp, equals('2001:b07:a3f:3f82:4a2:5548:c911:7969'));
  }, timeout: const Timeout(Duration(seconds: 25)));
}
