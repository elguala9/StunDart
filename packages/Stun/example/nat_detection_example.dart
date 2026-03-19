import 'package:stun/stun.dart';
import 'dart:io';

/// Example demonstrating NAT type detection using STUN
///
/// This example shows how to use the NATDetector class to determine
/// the type of NAT (Network Address Translation) that the client is behind.
///
/// Run with: dart run example/nat_detection_example.dart
void main() async {
  print('=== NAT Type Detection Example ===\n');

  // Create UDP socket (use port 0 for automatic assignment)
  print('Creating UDP socket...');
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  print('Socket bound to ${socket.address}:${socket.port}\n');

  // Create NAT detector with Google STUN server
  print('Creating NAT detector...');
  final detector = NATDetector(
    primaryServer: 'stun.l.google.com',
    primaryPort: 19302,
    socket: socket,
    timeout: const Duration(seconds: 5),
  );

  try {
    print('Starting NAT type detection (this may take 10-20 seconds)...\n');

    // Perform NAT detection
    final result = await detector.detectNATType();

    // Display results
    print('╔════════════════════════════════════════════════════════╗');
    print('║              NAT DETECTION RESULTS                     ║');
    print('╠════════════════════════════════════════════════════════╣');
    print('║ NAT Type:         ${_padRight(result.natType.displayName, 32)} ║');
    print(
      '║ Filtering:        ${_padRight(result.filteringBehavior.displayName, 32)} ║',
    );
    print(
      '║ Mapping:          ${_padRight(result.mappingBehavior.displayName, 32)} ║',
    );
    print('╠════════════════════════════════════════════════════════╣');
    print('║ Public IP:        ${_padRight(result.publicIp ?? 'N/A', 32)} ║');
    print(
      '║ Public Port:      ${_padRight(result.publicPort?.toString() ?? 'N/A', 32)} ║',
    );
    print(
      '║ Alternate IP:     ${_padRight(result.alternateIp ?? 'N/A', 32)} ║',
    );
    print(
      '║ Alternate Port:   ${_padRight(result.alternatePort?.toString() ?? 'N/A', 32)} ║',
    );
    print('╠════════════════════════════════════════════════════════╣');
    print(
      '║ RFC 5780 Support: ${_padRight(result.rfc5780Supported ? 'Yes' : 'No', 32)} ║',
    );
    print(
      '║ Detection Time:   ${_padRight('${result.detectionTime.inMilliseconds}ms', 32)} ║',
    );
    print('╚════════════════════════════════════════════════════════╝');

    // Display interpretation
    print('\n📖 What does this mean?\n');
    _explainNATType(result.natType);

    // Display detailed diagnostics
    if (result.diagnostics.isNotEmpty) {
      print('\n🔍 Detailed Test Results:\n');
      result.diagnostics.forEach((key, value) {
        print('  $key: $value');
      });
    }

    // Additional recommendations based on NAT type
    print('\n💡 Recommendations:\n');
    _provideRecommendations(result.natType);
  } catch (e) {
    print('\n❌ Error during NAT detection: $e');
    print('This could mean:');
    print('  - No internet connection');
    print('  - STUN server is unreachable');
    print('  - UDP traffic is blocked by firewall');
  } finally {
    socket.close();
    print('\n✓ Socket closed');
  }
}

/// Explain what each NAT type means
void _explainNATType(NATType natType) {
  switch (natType) {
    case NATType.openInternet:
      print('  Your device has a public IP address and is directly connected');
      print('  to the internet without any NAT. All incoming connections are');
      print('  allowed.');
      break;

    case NATType.fullCone:
      print('  Full Cone NAT (also called One-to-One NAT) allows any external');
      print(
        '  host to send packets to your device once you have sent a packet',
      );
      print('  to any destination. This is the most permissive type of NAT.');
      break;

    case NATType.restrictedCone:
      print('  Restricted Cone NAT only allows packets from external hosts');
      print(
        '  that you have previously sent packets to. The external host can',
      );
      print('  use any source port.');
      break;

    case NATType.portRestrictedCone:
      print('  Port Restricted Cone NAT is the most restrictive cone NAT. It');
      print('  only allows packets from a specific IP address AND port that');
      print('  you have previously sent packets to.');
      break;

    case NATType.symmetric:
      print('  Symmetric NAT assigns a different public port for each');
      print('  destination you communicate with. This makes peer-to-peer');
      print('  connections difficult without a relay server.');
      break;

    case NATType.symmetricFirewall:
      print('  Your device is behind a symmetric firewall that behaves');
      print('  similarly to Symmetric NAT. Direct peer-to-peer connections');
      print('  are challenging.');
      break;

    case NATType.udpBlocked:
      print('  UDP traffic appears to be completely blocked. This could be');
      print('  due to a firewall or network configuration. You may need to');
      print('  use TCP-based alternatives.');
      break;
  }
}

/// Provide recommendations based on NAT type
void _provideRecommendations(NATType natType) {
  switch (natType) {
    case NATType.openInternet:
    case NATType.fullCone:
      print('  ✓ Excellent for P2P applications');
      print('  ✓ No special configuration needed');
      print('  ✓ Direct connections should work');
      break;

    case NATType.restrictedCone:
    case NATType.portRestrictedCone:
      print('  ⚠ Good for most P2P applications');
      print('  ⚠ May need STUN for connection establishment');
      print('  ✓ ICE/STUN should work well');
      break;

    case NATType.symmetric:
    case NATType.symmetricFirewall:
      print('  ⚠ Difficult for P2P connections');
      print('  ⚠ STUN alone may not be sufficient');
      print('  ℹ Consider using TURN relay servers');
      print('  ℹ ICE with both STUN and TURN recommended');
      break;

    case NATType.udpBlocked:
      print('  ❌ UDP is blocked');
      print('  ℹ Consider TCP-based alternatives');
      print('  ℹ Contact network administrator if needed');
      print('  ℹ May need VPN to bypass restrictions');
      break;
  }
}

/// Helper to pad strings for table formatting
String _padRight(String text, int width) {
  if (text.length >= width) return text;
  return text + ' ' * (width - text.length);
}
