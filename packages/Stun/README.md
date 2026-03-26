# StunDart

[![pub package](https://img.shields.io/pub/v/stun.svg)](https://pub.dev/packages/stun)
[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

A complete Dart implementation of the STUN (Session Traversal Utilities for NAT) protocol for NAT traversal, public IP discovery, and NAT type detection.

## Features

✅ **Complete STUN Protocol Implementation**
- RFC 5389 compliant STUN Binding Request/Response
- RFC 5780 NAT Behavior Discovery support
- RFC 3489 legacy server compatibility
- XOR-MAPPED-ADDRESS attribute support
- Magic cookie validation and transaction ID tracking

✅ **NAT Type Detection** 🆕
- Automatic NAT type identification (7 types supported)
- Filtering behavior detection (endpoint-independent, address-dependent, address+port-dependent)
- Mapping behavior analysis
- Detailed diagnostic information
- Support for both RFC 5780 and RFC 3489 servers

✅ **Dual Stack Support**
- Full IPv4 support
- Full IPv6 support
- Automatic IP version detection
- Dual-stack compatibility testing

✅ **Flexible API**
- Clean interface-based design
- Type-safe record types
- Async/await API
- Configurable timeouts and servers
- Multiple STUN server support
- Global singleton pattern support
- Internal socket management options

✅ **Production Ready**
- Comprehensive test suite (177 tests)
- Error handling and validation
- Port mapping discovery
- Local network information
- Configurable timeout handling
- Optional logging support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  stun: ^1.4.1
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic STUN Request

```dart
import 'dart:io';
import 'package:stun/stun.dart';

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

### NAT Type Detection 🆕

Detect the type of NAT you're behind and understand your network connectivity:

```dart
import 'dart:io';
import 'package:stun/stun.dart';

void main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  final detector = NATDetector(
    primaryServer: 'stun.l.google.com',
    primaryPort: 19302,
    socket: socket,
  );

  try {
    final result = await detector.detectNATType();

    print('NAT Type: ${result.natType.displayName}');
    print('Filtering: ${result.filteringBehavior.displayName}');
    print('Mapping: ${result.mappingBehavior.displayName}');
    print('Public IP: ${result.publicIp}:${result.publicPort}');
    print('RFC 5780 Support: ${result.rfc5780Supported}');
    print('Detection Time: ${result.detectionTime.inMilliseconds}ms');
  } finally {
    socket.close();
  }
}
```

**Output example:**
```
NAT Type: Port Restricted Cone NAT
Filtering: Address and Port-Dependent Filtering
Mapping: Endpoint-Independent Mapping
Public IP: 203.0.113.42:54321
RFC 5780 Support: false
Detection Time: 2347ms
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

## NAT Types Detected

StunDart can identify the following NAT types according to RFC 5780:

| NAT Type | P2P Capability | Description |
|----------|---------------|-------------|
| **Open Internet** | ✅ Excellent | No NAT, direct public IP |
| **Full Cone NAT** | ✅ Excellent | Any external host can send packets |
| **Restricted Cone NAT** | ✅ Good | Only hosts you contacted can reply |
| **Port Restricted Cone NAT** | ⚠️ Good | Only specific IP:port combinations can reply |
| **Symmetric NAT** | ⚠️ Difficult | Different mapping for each destination |
| **Symmetric UDP Firewall** | ⚠️ Difficult | Firewall with symmetric behavior |
| **UDP Blocked** | ❌ Impossible | UDP traffic is completely blocked |

### Understanding NAT Behaviors

**Filtering Behavior:**
- **Endpoint-Independent**: Any external endpoint can send packets (best for P2P)
- **Address-Dependent**: Only IPs you contacted can reply
- **Address+Port-Dependent**: Only specific IP:port pairs can reply (most restrictive)

**Mapping Behavior:**
- **Endpoint-Independent**: Same public port for all destinations (best for P2P)
- **Address-Dependent**: Different port per destination IP
- **Address+Port-Dependent**: Different port per destination IP:port pair

## API Reference

### `NATDetector` Class 🆕

Detect NAT type using RFC 5780 algorithm:

```dart
class NATDetector {
  NATDetector({
    required String primaryServer,
    required int primaryPort,
    required RawDatagramSocket socket,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<NATDetectionResult> detectNATType();
}
```

### `NATDetectionResult` Type 🆕

Complete NAT detection information:

```dart
typedef NATDetectionResult = ({
  NATType natType,                      // Detected NAT type
  NATFilteringBehavior filteringBehavior,  // Filtering behavior
  NATMappingBehavior mappingBehavior,      // Mapping behavior
  String? publicIp,                     // Public IP address
  int? publicPort,                      // Public port
  String? alternateIp,                  // Alternate server IP
  int? alternatePort,                   // Alternate server port
  bool rfc5780Supported,                // RFC 5780 support flag
  Duration detectionTime,               // Time taken for detection
  Map<String, dynamic> diagnostics,     // Detailed test diagnostics
});
```

### `IStunHandlerSingleton` Interface 🆕

Singleton interface for managing dual IPv4/IPv6 STUN handlers:

```dart
abstract interface class IStunHandlerSingleton {
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  });
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  });
  IStunHandler get ipv4Handler;
  IStunHandler? get ipv6Handler;
  void setIpv4Handler(IStunHandler handler);
  void setIpv6Handler(IStunHandler? handler);
  void replaceHandler(IStunHandler handler, {required bool ipv6});
  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();
  Future<bool> pingStunServer({bool ipv6 = true});
  RawDatagramSocket getSocket({bool ipv6 = true});
  void setStunServer(String address, int port, {bool? ipv6});
  void close({bool? ipv6});
}
```

### `StunHandlerSingleton` Class 🆕

Global singleton instance managing dual IPv4/IPv6 STUN handlers:

```dart
class StunHandlerSingleton implements IStunHandlerSingleton {
  static StunHandlerSingleton get instance => _instance;

  /// Initialize with both IPv4 and IPv6 handlers
  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
  });

  /// Initialize with provided handler instances (DI/testing)
  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  });

  /// Get the IPv4 handler (always available after initialize)
  IStunHandler get ipv4Handler;

  /// Get the IPv6 handler (null if unavailable)
  IStunHandler? get ipv6Handler;

  /// Perform STUN request on both handlers, return IPv6 if available
  Future<StunResponse> performStunRequest();

  /// Get local info from both handlers, return IPv6 if available
  Future<LocalInfo> performLocalRequest();
}
```

**Example:**
```dart
// Initialize global singleton with both IPv4 and IPv6
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
);

// Use automatically (prefers IPv6 if available)
final response = await StunHandlerSingleton.instance.performStunRequest();

// Access specific handler
final ipv4Response = await StunHandlerSingleton.instance.ipv4Handler.performStunRequest();
final ipv6Response = await StunHandlerSingleton.instance.ipv6Handler?.performStunRequest();

// Replace specific handler
final customHandler = await StunHandler.withoutSocket(
  address: 'custom.stun.server',
  port: 3478,
  ipv6: true,
);
StunHandlerSingleton.instance.replaceHandler(
  customHandler,
  ipv6: true,
);
```

### `StunHandler` Constructors 🆕

Multiple ways to create STUN handlers:

```dart
// Traditional: You manage the socket
final handler = StunHandler((
  address: 'stun.l.google.com',
  port: 19302,
  socket: socket,  // External socket ownership
));

// With internal socket management
final handler = StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  ipv6: false,  // IPv4 (default)
);

// IPv6 variant
final handler = StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  ipv6: true,  // Use IPv6
);

// With configurable timeout and logging
final handler = StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  timeout: const Duration(seconds: 10),  // Custom timeout
  onLog: (msg) => print('STUN: $msg'),   // Optional logging
);
```

### Configurable Timeout

By default, STUN requests timeout after 5 seconds. You can customize this:

```dart
// Custom timeout for factory
final handler = await StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  timeout: const Duration(seconds: 15),  // 15 second timeout
);

// Custom timeout for singleton
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
  timeout: const Duration(seconds: 10),
);

// With external socket
final handler = StunHandler.withSocket(
  socket,
  timeout: const Duration(seconds: 20),
);
```

### Logging Support

Enable optional logging to track STUN operations:

```dart
final messages = <String>[];

// With logging callback
final handler = await StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  onLog: (msg) => messages.add(msg),
);

try {
  final response = await handler.performStunRequest();
  // messages contains: Socket creation, request sending, response parsing
  for (final msg in messages) {
    print('🔍 $msg');
  }
} finally {
  handler.close();
}

// With singleton
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
  onLog: (msg) => logger.info(msg),  // Your logger
);
```

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

### Enums

```dart
enum NATType {
  openInternet,
  fullCone,
  restrictedCone,
  portRestrictedCone,
  symmetric,
  symmetricFirewall,
  udpBlocked,
}

enum NATFilteringBehavior {
  endpointIndependent,
  addressDependent,
  addressAndPortDependent,
  unknown,
}

enum NATMappingBehavior {
  endpointIndependent,
  addressDependent,
  addressAndPortDependent,
  unknown,
}

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

### Complete NAT Detection Example

```dart
import 'dart:io';
import 'package:stun/stun.dart';

void main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  final detector = NATDetector(
    primaryServer: 'stun.l.google.com',
    primaryPort: 19302,
    socket: socket,
    timeout: const Duration(seconds: 5),
  );

  try {
    final result = await detector.detectNATType();

    // Display results
    print('═══════════════════════════════════════');
    print('NAT Type: ${result.natType.displayName}');
    print('Filtering: ${result.filteringBehavior.displayName}');
    print('Mapping: ${result.mappingBehavior.displayName}');
    print('═══════════════════════════════════════');
    print('Public IP: ${result.publicIp}');
    print('Public Port: ${result.publicPort}');
    print('Alternate Server: ${result.alternateIp}:${result.alternatePort}');
    print('RFC 5780 Support: ${result.rfc5780Supported}');
    print('Detection Time: ${result.detectionTime.inMilliseconds}ms');

    // Access detailed diagnostics
    print('\nDiagnostics:');
    result.diagnostics.forEach((key, value) {
      print('  $key: $value');
    });

    // Provide recommendations
    switch (result.natType) {
      case NATType.openInternet:
      case NATType.fullCone:
        print('\n✓ Excellent for P2P applications!');
        break;
      case NATType.symmetric:
        print('\n⚠ Difficult for P2P - consider using TURN relay');
        break;
      case NATType.udpBlocked:
        print('\n❌ UDP is blocked - use TCP alternatives');
        break;
      default:
        print('\n⚠ May need STUN for P2P connections');
    }
  } finally {
    socket.close();
  }
}
```

### Dual Stack (IPv4 + IPv6)

```dart
import 'dart:io';
import 'package:stun/stun.dart';

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

### Internal Socket Management

```dart
import 'package:stun/stun.dart';

void main() async {
  // Create handler with internal socket management
  final handler = await StunHandler.withoutSocket(
    address: 'stun.l.google.com',
    port: 19302,
    ipv6: false,  // IPv4
  );

  try {
    final response = await handler.performStunRequest();
    print('Public IP: ${response.publicIp}');
    print('Public Port: ${response.publicPort}');
  } finally {
    handler.close();  // Closes internal socket
  }
}
```

### Global Singleton Pattern

```dart
import 'package:stun/stun.dart';

void main() async {
  // Initialize global singleton with IPv4 and IPv6
  await StunHandlerSingleton.instance.initialize(
    address: 'stun.l.google.com',
    port: 19302,
  );

  // Use anywhere in your app (prefers IPv6 if available)
  final response = await StunHandlerSingleton.instance.performStunRequest();
  print('Public IP: ${response.publicIp}');

  // Switch servers without creating new handler
  StunHandlerSingleton.instance.setStunServer('stun1.l.google.com', 19302);
  final response2 = await StunHandlerSingleton.instance.performStunRequest();

  // Access specific handler if needed
  final ipv4Handler = StunHandlerSingleton.instance.ipv4Handler;
  final ipv6Handler = StunHandlerSingleton.instance.ipv6Handler;

  // Cleanup
  StunHandlerSingleton.instance.close();
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

### Multiple Servers for Validation

```dart
final servers = [
  ('stun.l.google.com', 19302),
  ('stun1.l.google.com', 19302),
  ('stun.stunprotocol.org', 3478),
];

for (final (server, port) in servers) {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final detector = NATDetector(
    primaryServer: server,
    primaryPort: port,
    socket: socket,
  );

  final result = await detector.detectNATType();
  print('$server: ${result.natType.displayName}');
  socket.close();
}
```

## Testing

Run the comprehensive test suite:

```bash
cd packages/StunDartTests
dart test
```

The test suite includes:
- **24 tests** for StunHandlerSingleton (dual stack management, handler replacement, IPv6 preference, timeout, logging)
- **16 tests** for NAT type enums and typedefs
- **24 tests** for STUN message parsing and encoding
- **18 tests** for NAT detector integration
- **11 tests** for StunHandler (withoutSocket, IPv4/IPv6, timeout, logging)
- **6 tests** for response caching behavior
- IPv4 and IPv6 connectivity tests
- Dual stack tests
- STUN server comparison tests
- Configurable timeout handling tests
- Logging support tests
- Edge case and socket lifecycle tests

**Total: 177 tests - All passing ✅**

### `StunHandlerBase` & DI Integration

`StunHandlerBase` is the injectable base class behind `StunHandlerSingleton`. It can be subclassed for custom DI frameworks:

```dart
import 'package:stun/stun.dart';
import 'package:singleton_manager/singleton_manager.dart';

// Initialize via stun_di helpers
await initialPointStun(
  address: 'stun.l.google.com',
  port: 19302,
);

// Retrieve the singleton from the DI container
final stun = SingletonDIAccess.get<StunHandlerBase>();
final response = await stun.performStunRequest();
print('Public IP: ${response.publicIp}');

// Listen to socket refresh events via IDualCallbackHandler
final callbacks = SingletonDIAccess.get<IDualCallbackHandler>();
callbacks.registerIpv4((data) {
  final (newResponse, oldResponse) = data;
  print('IPv4 socket refreshed → ${newResponse.publicIp}');
});
```

## Architecture

StunDart follows a clean architecture with separation of concerns:

```
packages/Stun/lib/src/
├── types/                        # Type definitions (records, enums)
│   └── stun_types.dart
├── interfaces/                   # Abstract interfaces
│   ├── i_stun_handler.dart
│   ├── i_stun_handler_singleton.dart
│   ├── i_dual_stun_handler.dart
│   └── i_dual_callback_handler.dart
├── di/                           # DI entry points
│   └── stun_di.dart
└── implementations/              # Concrete implementations
    ├── handlers/
    │   ├── stun_handler.dart          # Main STUN handler
    │   └── dual_stun_handler.dart     # Dual IPv4/IPv6 handler
    ├── singleton/
    │   ├── stun_handler_base.dart     # Injectable base class
    │   └── stun_handler_singleton.dart
    ├── nat/
    │   └── nat_detector.dart          # NAT type detection
    ├── socket/                        # Socket lifecycle management
    ├── request/                       # STUN message encoding/decoding
    └── config/                        # Constants and configuration
```

### Developer Tooling

The `stun.dart` barrel file is auto-generated by [`index_generator`](https://pub.dev/packages/index_generator). After adding new public files, regenerate it with:

```bash
melos run barrels
```

Configuration lives in `packages/Stun/pubspec.yaml` under the `index_generator:` key.

## Protocol Details

### STUN Attributes Supported

| Attribute | Type | RFC | Purpose |
|-----------|------|-----|---------|
| XOR-MAPPED-ADDRESS | 0x0020 | 5389 | Public IP/port (XOR encoded) |
| MAPPED-ADDRESS | 0x0001 | 5389 | Public IP/port (plain) |
| CHANGE-REQUEST | 0x0003 | 5780 | Request alternate server response |
| CHANGED-ADDRESS | 0x0005 | 3489 | Alternate server (legacy) |
| RESPONSE-ORIGIN | 0x802b | 5780 | Source of response |
| OTHER-ADDRESS | 0x802c | 5780 | Alternate server address |

### Message Format

- **Message Type:** 0x0001 (Binding Request)
- **Magic Cookie:** 0x2112A442
- **Transaction ID:** 12 cryptographically secure random bytes
- **Attribute Padding:** 4-byte boundary alignment

## Requirements

- **Dart SDK:** ^3.9.4
- **Network:** UDP connectivity
- **Platform:** All Dart platforms (VM, Web, Mobile)
- **IP Support:** IPv4 and/or IPv6

## Performance

- Basic STUN request: < 100ms (typical)
- NAT type detection: 2-10 seconds (4 sequential tests)
- Memory efficient: Minimal allocations
- No external dependencies

## Use Cases

✅ **P2P Applications**
- WebRTC connection establishment
- Peer-to-peer gaming
- Direct file transfers
- VoIP applications

✅ **Network Diagnostics**
- NAT type identification
- Connectivity testing
- Firewall detection
- Network troubleshooting

✅ **Security & Privacy**
- Public IP discovery
- Network fingerprinting prevention
- Privacy-aware applications

✅ **IoT & Embedded**
- Device connectivity testing
- NAT traversal for IoT devices
- Remote access setup

## Contributing

Contributions are welcome! Please ensure:
- All tests pass (`dart test`)
- Code follows Dart style guidelines (`dart analyze`)
- New features include tests and documentation
- Update CHANGELOG.md

## License

This project is licensed under the **GNU Lesser General Public License v3.0 (LGPL-3.0)**.

See the [LICENSE](LICENSE) file for details.

## References

- [RFC 5389 - STUN Protocol](https://tools.ietf.org/html/rfc5389)
- [RFC 5780 - NAT Behavior Discovery](https://tools.ietf.org/html/rfc5780)
- [RFC 3489 - STUN (Classic)](https://tools.ietf.org/html/rfc3489)
- [STUN Protocol Overview](https://en.wikipedia.org/wiki/STUN)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and migration guides.

## Support

- 📫 Issues: [GitHub Issues](https://github.com/elguala9/StunDart/issues)
- 📦 Package: [pub.dev](https://pub.dev/packages/stun)
- 📖 Documentation: [API Docs](https://pub.dev/documentation/stun/latest/)

---

Made with ❤️ by the StunDart team
