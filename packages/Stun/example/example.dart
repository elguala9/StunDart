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
    print('   Local IP: ${localInfo.localIp}');
    print('   Local Port: ${localInfo.localPort}\n');

    // 2. Perform STUN request to get public IP
    print('2. Performing STUN request...');
    final response = await handler.performStunRequest();
    print('   ✅ Success!');
    print('   Public IP: ${response.publicIp}');
    print('   Public Port: ${response.publicPort}');
    print('   IP Version: ${response.ipVersion.value}');
    print('   Port Mapping: ${localInfo.localPort} → ${response.publicPort}');

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
    print('   Public IP from second server: ${response2.publicIp}');

    // Verify both servers report the same IP
    if (response.publicIp == response2.publicIp) {
      print('   ✅ Both servers agree on public IP');
    }

    handler2.close();
  } catch (e) {
    print('Error: $e');
  } finally {
    handler.close();
  }
}

/// Example 3: DI-based singleton using StunHandlerBase and IDualCallbackHandler
Future<void> _exampleWithDI() async {
  try {
    // Initialize the DI container with IPv4 (+ IPv6 if available)
    await initialPointStun(
      address: 'stun.l.google.com',
      port: 19302,
    );

    print('✅ DI container initialized\n');

    // Retrieve the singleton from the container
    final stun = SingletonDIAccess.get<StunHandlerBase>();

    // Register a socket refresh callback via IDualCallbackHandler
    final callbacks = SingletonDIAccess.get<IDualCallbackHandler>();
    callbacks.registerIpv4((data) {
      final (newResponse, _) = data;
      print('   [callback] IPv4 socket refreshed → ${newResponse.publicIp}');
    });

    // Perform requests through the injected singleton
    print('1. Performing STUN request via DI singleton...');
    final response = await stun.performStunRequest();
    final stunIpv4 = response.stunResponseIpv4;
    final stunIpv6 = response.stunResponseIpv6;
    if (stunIpv4 != null) {
      print('   IPv4 Public IP: ${stunIpv4.publicIp}');
    }
    if (stunIpv6 != null) {
      print('   IPv6 Public IP: ${stunIpv6.publicIp}');
    }

    print('2. Performing local request...');
    final localInfo = await stun.performLocalRequest();
    final localIpv4 = localInfo.localDualInfoIpv4;
    final localIpv6 = localInfo.localDualInfoIpv6;
    if (localIpv4 != null) {
      print('   IPv4 Local: ${localIpv4.localIp}:${localIpv4.localPort}');
    }
    if (localIpv6 != null) {
      print('   IPv6 Local: ${localIpv6.localIp}:${localIpv6.localPort}');
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
      ipv6: false, // Set to true for IPv6
    );

    print('✅ Handler created with automatic socket management\n');

    // 1. Get local network information
    print('1. Getting local network information...');
    final localInfo = await handler.performLocalRequest();
    print('   Local IP: ${localInfo.localIp}');
    print('   Local Port: ${localInfo.localPort}\n');

    // 2. Ping STUN server
    print('2. Pinging STUN server...');
    final isReachable = await handler.pingStunServer();
    print('   Server reachable: $isReachable\n');

    // 3. Perform STUN request (socket auto-recreates on network errors)
    print('3. Performing STUN request...');
    final response = await handler.performStunRequest();
    print('   ✅ Success!');
    print('   Public IP: ${response.publicIp}');
    print('   Public Port: ${response.publicPort}');
    print('   IP Version: ${response.ipVersion.value}');
    print('   Port Mapping: ${localInfo.localPort} → ${response.publicPort}');

    handler.close();
  } catch (e) {
    print('Error: $e');
  }
}
