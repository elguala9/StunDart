import 'dart:io';

void main() async {
  print('=== IPv6 Network Diagnostic ===\n');
  
  // Test 1: Check if IPv6 socket can be created
  print('1. Testing IPv6 socket creation...');
  try {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
    print('   ✅ IPv6 socket created successfully');
    print('   - Port: ${socket.port}');
    print('   - Address: ${socket.address}');
    socket.close();
  } catch (e) {
    print('   ❌ Failed: $e');
    return;
  }
  
  // Test 2: Check IPv6 interfaces
  print('\n2. Checking IPv6 network interfaces...');
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv6);
  if (interfaces.isEmpty) {
    print('   ❌ No IPv6 interfaces found');
  } else {
    print('   ✅ Found ${interfaces.length} IPv6 interface(s):');
    for (final iface in interfaces) {
      print('   - ${iface.name}:');
      for (final addr in iface.addresses) {
        print('     ${addr.address} (${addr.isLinkLocal ? "link-local" : "global"})');
      }
    }
  }
  
  // Test 3: DNS lookup for IPv6
  print('\n3. Testing DNS lookup for IPv6...');
  try {
    final addrs = await InternetAddress.lookup(
      'stun.l.google.com',
      type: InternetAddressType.IPv6,
    );
    print('   ✅ Found ${addrs.length} IPv6 address(es):');
    for (final addr in addrs) {
      print('   - ${addr.address}');
    }
  } catch (e) {
    print('   ❌ Failed: $e');
  }
  
  // Test 4: Try to send/receive UDP packet on IPv6
  print('\n4. Testing UDP on IPv6...');
  try {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
    print('   ✅ Socket bound to ${socket.address}:${socket.port}');
    
    // Try to resolve and send to Google STUN
    final stunAddrs = await InternetAddress.lookup(
      'stun.l.google.com',
      type: InternetAddressType.IPv6,
    );
    
    if (stunAddrs.isNotEmpty) {
      final target = stunAddrs.first;
      print('   📤 Sending test packet to $target:19302...');
      
      // Simple STUN binding request (simplified)
      final testPacket = [
        0x00, 0x01, // Binding Request
        0x00, 0x00, // Length
        0x21, 0x12, 0xA4, 0x42, // Magic Cookie
        ...List.filled(12, 0x00), // Transaction ID
      ];
      
      final sent = socket.send(testPacket, target, 19302);
      print('   📤 Sent $sent bytes');
      
      // Wait for response
      print('   ⏳ Waiting for response (5 seconds)...');
      
      bool received = false;
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            print('   ✅ Received ${datagram.data.length} bytes from ${datagram.address}:${datagram.port}');
            received = true;
            socket.close();
          }
        }
      });
      
      await Future<void>.delayed(const Duration(seconds: 5));
      
      if (!received) {
        print('   ❌ No response received (timeout)');
        print('   ℹ️  This suggests:');
        print('      - Firewall blocking IPv6 UDP');
        print('      - Router not forwarding IPv6 properly');
        print('      - ISP filtering STUN traffic on IPv6');
        socket.close();
      }
    }
  } catch (e) {
    print('   ❌ Failed: $e');
  }
  
  print('\n=== Diagnostic Complete ===');
  print('\nIf you can create IPv6 socket but not receive STUN response,');
  print('check your firewall/router settings for IPv6 UDP traffic.');
}
