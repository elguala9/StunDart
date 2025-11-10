# StunDart

A complete Dart implementation of the STUN (Session Traversal Utilities for NAT) protocol for NAT traversal and public IP discovery.

## Features

✅ **STUN Protocol Implementation**
- RFC 5389 compliant STUN Binding Request/Response
- XOR-MAPPED-ADDRESS attribute support
- Magic cookie validation
- Transaction ID tracking

✅ **Dual Stack Support**
- Full IPv4 support
- Full IPv6 support
- Automatic IP version detection

✅ **Flexible API**
- Clean interface-based design
- Record types for type safety
- Async/await API
- Configurable timeouts and servers

✅ **Production Ready**
- Comprehensive test suite
- Error handling and validation
- Port mapping discovery
- Local network information

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  stundart: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic STUN Request

```dart
import 'dart:io';
import 'package:stundart/stundart.dart';

void main() async {
  // Create a UDP socket
  final socket = await RawDatagramSocket.bind(
    InternetAddress.anyIPv4,
    0, // Use any available port
  );

  // Configure STUN handler
  final input = (
    address: 'stun.l.google.com',
    port: 19302,
    socket: socket,
  );

  final handler = StunHandler(input);

  try {
    // Perform STUN request
    final response = await handler.performStunRequest();

    print('Public IP: ${response.publicIp}');
    print('Public Port: ${response.publicPort}');
    print('IP Version: ${response.ipVersion.value}');
  } finally {
    handler.close();
  }
}
```

### IPv6 Support

```dart
// Create IPv6 socket
final socket = await RawDatagramSocket.bind(
  InternetAddress.anyIPv6,
  0,
);

final input = (
  address: 'stun.l.google.com',
  port: 19302,
  socket: socket,
);

final handler = StunHandler(input);
final response = await handler.performStunRequest();

print('Public IPv6: ${response.publicIp}');
```

### Get Local Network Information

```dart
final handler = StunHandler(input);

// Get local IP and port without contacting STUN server
final localInfo = await handler.performLocalRequest();

print('Local IP: ${localInfo.localIp}');
print('Local Port: ${localInfo.localPort}');
```

### Change STUN Server Dynamically

```dart
final handler = StunHandler(input);

// Change to a different STUN server
handler.setStunServer('stun1.l.google.com', 19302);

final response = await handler.performStunRequest();
```

### Verify STUN Server Connectivity

```dart
final handler = StunHandler(input);

// Ping STUN server to verify reachability
final isReachable = await handler.pingStunServer();

if (isReachable) {
  print('STUN server is reachable');
}
```

## API Reference

### `IStunHandler` Interface

Main interface for STUN operations:

```dart
abstract class IStunHandler {
  /// Performs a STUN request and returns the public (IP, port)
  Future<StunResponse> performStunRequest();

  /// Retrieves local (IP, port) information
  Future<LocalInfo> performLocalRequest();

  /// Verifies the reachability of the configured STUN server
  Future<bool> pingStunServer();

  /// Sets the STUN server address/port
  void setStunServer(String address, int port);

  /// Returns the underlying socket
  RawDatagramSocket getSocket();

  /// Closes the socket and releases resources
  void close();
}
```

### `StunResponse` Type

Response from a STUN request:

```dart
typedef StunResponse = ({
  String publicIp,           // Public IP address
  int publicPort,            // Public port
  IpVersion ipVersion,       // IPv4 or IPv6
  Uint8List transactionId,   // Transaction ID (12 bytes)
  Uint8List raw,             // Raw STUN packet
  Map<String, dynamic>? attrs, // Additional attributes
});
```

### `LocalInfo` Type

Local network information:

```dart
typedef LocalInfo = ({
  String localIp,    // Local IP address
  int localPort,     // Local port
});
```

### `StunHandlerInput` Type

Input parameters for StunHandler constructor:

```dart
typedef StunHandlerInput = ({
  String? address,              // STUN server address (optional)
  int? port,                    // STUN server port (optional)
  RawDatagramSocket socket,     // UDP socket (required)
});
```

### `IpVersion` Enum

IP version indicator:

```dart
enum IpVersion {
  v4('IPv4'),
  v6('IPv6');
}
```

## Public STUN Servers

You can use these public STUN servers for testing:

**Google STUN Servers:**
- `stun.l.google.com:19302`
- `stun1.l.google.com:19302`
- `stun2.l.google.com:19302`
- `stun3.l.google.com:19302`
- `stun4.l.google.com:19302`

**Other Providers:**
- `stun.stunprotocol.org:3478`
- `stun.voip.blackberry.com:3478`

## Examples

### Dual Stack (IPv4 + IPv6)

```dart
import 'dart:io';
import 'package:stundart/stundart.dart';

Future<void> dualStackExample() async {
  // Test IPv4
  final socket4 = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final input4 = (address: 'stun.l.google.com', port: 19302, socket: socket4);
  final handler4 = StunHandler(input4);
  
  final response4 = await handler4.performStunRequest();
  print('IPv4: ${response4.publicIp}');
  handler4.close();
  
  // Test IPv6
  final socket6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
  final input6 = (address: 'stun.l.google.com', port: 19302, socket: socket6);
  final handler6 = StunHandler(input6);
  
  final response6 = await handler6.performStunRequest();
  print('IPv6: ${response6.publicIp}');
  handler6.close();
}
```

### With Timeout Handling

```dart
try {
  final response = await handler.performStunRequest()
      .timeout(const Duration(seconds: 10));
  
  print('Success: ${response.publicIp}');
} on TimeoutException {
  print('STUN request timed out');
} on SocketException catch (e) {
  print('Network error: $e');
}
```

## Testing

Run the test suite:

```bash
cd packages/StunDartTests
dart test
```

The test suite includes:
- IPv4 and IPv6 connectivity tests
- Dual stack tests
- STUN server comparison tests
- Timeout handling tests
- Configuration change tests
- Local network information tests

## Architecture

StunDart follows a clean architecture with separation of concerns:

```
packages/StunDart/lib/src/
├── types/                   # Type definitions (records, enums)
│   └── stun_types.dart
├── interfaces/              # Abstract interfaces
│   └── i_stun_handler.dart
└── implementations/         # Concrete implementations
    ├── stun_handler.dart    # Main STUN handler
    ├── stun_message.dart    # STUN message parser
    └── stun_config.dart     # Default configuration
```

## Protocol Details

StunDart implements the STUN Binding Request/Response:

- **Message Type:** 0x0001 (Binding Request)
- **Magic Cookie:** 0x2112A442
- **Transaction ID:** 12 random bytes
- **Attributes Supported:**
  - XOR-MAPPED-ADDRESS (0x0020)
  - MAPPED-ADDRESS (0x0001)

## Requirements

- Dart SDK ^3.9.4
- Network connectivity (UDP)
- IPv4 or IPv6 support (depending on use case)

## Contributing

Contributions are welcome! Please ensure:
- All tests pass
- Code follows Dart style guidelines
- New features include tests

## License

[Your License Here]

## References

- [RFC 5389 - STUN Protocol](https://tools.ietf.org/html/rfc5389)
- [STUN Protocol Overview](https://en.wikipedia.org/wiki/STUN)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
