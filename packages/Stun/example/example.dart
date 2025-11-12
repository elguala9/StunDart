import 'dart:io';
import 'package:stun/stun.dart';

/// Example demonstrating basic STUN usage for NAT discovery
/// 
/// This example shows how to:
/// - Create a STUN handler
/// - Perform a STUN request to discover your public IP
/// - Get local network information
/// - Ping a STUN server
void main() async {
  print('=== STUN Example ===\n');

  // Create a UDP socket
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  print('Local socket created on port: ${socket.port}\n');

  // Configure STUN handler
  final input = (
    address: 'stun.l.google.com',
    port: 19302,
    socket: socket,
  );

  final handler = StunHandler(input);

  try {
    // 1. Get local network information
    print('1. Getting local network information...');
    final localInfo = await handler.performLocalRequest();
    print('   Local IP: ${localInfo.localIp}');
    print('   Local Port: ${localInfo.localPort}\n');

    // 2. Ping STUN server
    print('2. Pinging STUN server...');
    final isReachable = await handler.pingStunServer();
    print('   Server reachable: $isReachable\n');

    // 3. Perform STUN request to get public IP
    print('3. Performing STUN request...');
    final response = await handler.performStunRequest();
    print('   ✅ Success!');
    print('   Public IP: ${response.publicIp}');
    print('   Public Port: ${response.publicPort}');
    print('   IP Version: ${response.ipVersion.value}');
    print('   Port Mapping: ${localInfo.localPort} → ${response.publicPort}');

    // 4. Try different STUN server
    print('\n4. Trying different STUN server...');
    handler.setStunServer('stun1.l.google.com', 19302);
    final response2 = await handler.performStunRequest();
    print('   Public IP from second server: ${response2.publicIp}');

    // Verify both servers report the same IP
    if (response.publicIp == response2.publicIp) {
      print('   ✅ Both servers agree on public IP');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    handler.close();
    print('\n=== Example Complete ===');
  }
}
