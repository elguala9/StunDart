import 'dart:io';
import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';

void main() async {
  print('=== STUN Example ===\n');

  // Pattern 1: Using external socket (traditional approach)
  print('--- Pattern 1: External Socket Management ---\n');
  await _exampleWithExternalSocket();

  print('\n--- Pattern 2: Internal Socket Management ---\n');
  // Pattern 2: Let StunHandler manage the socket internally
  await _exampleWithInternalSocket();

  print('\n--- Pattern 3: DI-based Singleton ---\n');
  await _exampleWithDI();

  print('\n=== Example Complete ===');
}

/// Example 1: Traditional approach with external socket management
Future<void> _exampleWithExternalSocket() async {
  // Create a UDP socket manually
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  print('Local socket created on port: ${socket.port}\n');

  // Configure STUN handler with external socket
  final input = (address: 'stun.l.google.com', port: 19302, socket: socket);

  final handler = StunHandler(input);

  try {
    // 1. Get local network information
    print('1. Getting local network information...');
    final localInfo = await handler.performLocalRequest();
    print('   Local IP: ${localInfo.localIpv4}');
    print('   Local Port: ${localInfo.localPortIpv4}\n');

    // 2. Perform STUN request to get public IP
    print('2. Performing STUN request...');
    final response = await handler.performStunRequest();
    print('   ✅ Success!');
    print('   Public IP: ${response.publicIp(InternetAddressType.IPv4)}');
    print('   Public Port: ${response.publicPort(InternetAddressType.IPv4)}');
    print('   IP Version: IPv4');
    print('   Port Mapping: ${localInfo.localPortIpv4} → ${response.publicPort(InternetAddressType.IPv4)}');

    // 3. Try different STUN server with NEW socket
    // (RawDatagramSocket streams are single-subscription, so create a new socket)
    print('\n3. Trying different STUN server with new socket...');
    handler.close();
    final socket2 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final handler2 = StunHandler((
      address: 'stun1.l.google.com',
      port: 19302,
      socket: socket2,
    ));
    final response2 = await handler2.performStunRequest();
    print('   Public IP from second server: ${response2.publicIp(InternetAddressType.IPv4)}');

    // Verify both servers report the same IP
    if (response.publicIp(InternetAddressType.IPv4) == response2.publicIp(InternetAddressType.IPv4)) {
      print('   ✅ Both servers agree on public IP');
    }

    handler2.close();
  } catch (e) {
    print('Error: $e');
  } finally {
    handler.close();
  }
}

/// Example 3: DI-based singleton using DualStunHandlerBase and IDualCallbackHandler
Future<void> _exampleWithDI() async {
  try {
    // Initialize the DI container with IPv4 (+ IPv6 if available)
    await initialPointStun(
      address: 'stun.l.google.com',
      port: 19302,
    );

    print('✅ DI container initialized\n');

    // Retrieve the singleton from the container
    final stun = SingletonDIAccess.get<DualStunHandlerBase>();

    // Register a socket refresh callback via IDualCallbackHandler
    final callbacks = SingletonDIAccess.get<IDualCallbackHandler>();
    callbacks.register((data) {
      final (newResponse, _) = data;
      print('   [callback] IPv4 socket refreshed → ${newResponse.publicIp(InternetAddressType.IPv4)}');
    }, type: InternetAddressType.IPv4);

    // Perform requests through the injected singleton
    print('1. Performing STUN request via DI singleton...');
    final response = await stun.performStunRequest();
    if (response.publicIp(InternetAddressType.IPv4) != null) {
      print('   IPv4 Public IP: ${response.publicIp(InternetAddressType.IPv4)}');
    }
    if (response.publicIp(InternetAddressType.IPv6) != null) {
      print('   IPv6 Public IP: ${response.publicIp(InternetAddressType.IPv6)}');
    }

    print('2. Performing local request...');
    final localInfo = await stun.performLocalRequest();
    if (localInfo.localIpv4 != null) {
      print('   IPv4 Local: ${localInfo.localIpv4}:${localInfo.localPortIpv4}');
    }
    if (localInfo.localIpv6 != null) {
      print('   IPv6 Local: ${localInfo.localIpv6}:${localInfo.localPortIpv6}');
    }

    stun.close();
  } catch (e) {
    print('Error: $e');
  }
}

/// Example 2: Modern approach with internal socket management
Future<void> _exampleWithInternalSocket() async {
  try {
    // Create handler with internal socket management (factory method)
    // Socket is created automatically and can be recreated on network errors
    final handler = await StunHandler.withoutSocket(
      address: 'stun.l.google.com',
      port: 19302,
      type: InternetAddressType.IPv4, // Set to InternetAddressType.IPv6 for IPv6
    );

    print('✅ Handler created with automatic socket management\n');

    // 1. Get local network information
    print('1. Getting local network information...');
    final localInfo = await handler.performLocalRequest();
    print('   Local IP: ${localInfo.localIpv4}');
    print('   Local Port: ${localInfo.localPortIpv4}\n');

    // 2. Ping STUN server
    print('2. Pinging STUN server...');
    final isReachable = await handler.pingStunServer();
    print('   Server reachable: $isReachable\n');

    // 3. Perform STUN request (socket auto-recreates on network errors)
    print('3. Performing STUN request...');
    final response = await handler.performStunRequest();
    print('   ✅ Success!');
    print('   Public IP: ${response.publicIp(InternetAddressType.IPv4)}');
    print('   Public Port: ${response.publicPort(InternetAddressType.IPv4)}');
    print('   IP Version: IPv4');
    print('   Port Mapping: ${localInfo.localPortIpv4} → ${response.publicPort(InternetAddressType.IPv4)}');

    handler.close();
  } catch (e) {
    print('Error: $e');
  }
}
