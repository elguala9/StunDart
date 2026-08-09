# StunDart

[![pub package](https://img.shields.io/pub/v/stun.svg)](https://pub.dev/packages/stun)
[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

A complete Dart implementation of the STUN (Session Traversal Utilities for NAT) protocol for NAT traversal, public IP discovery, and NAT type detection.

**IPv6 is the primary protocol of this project.** Every dual-stack API defaults to IPv6 when no `type`/family is specified, and IPv4 is an optional companion — either family alone is sufficient.

## Features

✅ **Complete STUN Protocol Implementation**
- RFC 5389 compliant STUN Binding Request/Response
- RFC 5780 NAT Behavior Discovery support
- RFC 3489 legacy server compatibility
- XOR-MAPPED-ADDRESS attribute support
- Magic cookie validation and transaction ID tracking

✅ **NAT Type Detection**
- Automatic NAT type identification (7 types supported)
- Filtering behavior detection (endpoint-independent, address-dependent, address+port-dependent)
- Mapping behavior analysis
- Optional secondary STUN server fallback for symmetric-NAT detection against servers without RFC 5780/3489 support

✅ **Dual Stack Support**
- IPv6-first, with IPv4 as an optional companion (either family alone is sufficient)
- Parallel request execution across both families
- Per-family socket replacement and migration

✅ **Flexible API**
- Clean interface-based design
- Type-safe record types
- Async/await API
- Configurable timeouts and servers
- Multiple STUN server support, with named presets and runtime switching
- Global singleton pattern support
- Dependency-injection integration via `singleton_manager`
- Internal socket management options

✅ **Production Ready**
- Comprehensive test suite (239 tests)
- Error handling and validation
- Local network information
- Configurable timeout handling
- Optional logging support

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  stun: ^1.7.0
```

Then run:

```bash
dart pub get
```

## Configuration

Every default (STUN server, port, timeout, IP family, NAT detector servers)
lives in the `stun` sector of
[`config_manager`](https://pub.dev/packages/config_manager). Set them once at
startup and every constructor picks them up — no need to repeat the same
arguments at each call site.

```dart
import 'package:stun/stun.dart';

void main() async {
  initStunConfig({
    'server': {'address': 'stun.cloudflare.com', 'port': 3478},
    'ipVersion': 'IPv6',
    'timeoutSeconds': 3,
  });

  // Uses the configured server, port, IP family and timeout.
  final handler = await StunHandler.withoutSocket();
}
```

`initStunConfig` deep-merges its argument onto `defaultStunConfig`, so a
partial map is enough: everything you leave out keeps its built-in value, and
the package works with no configuration at all. The full shape:

```json
{
  "server": { "address": "stun.l.google.com", "port": 19302, "localPort": 49152 },
  "ipVersion": "IPv6",
  "timeoutSeconds": 5,
  "nat": {
    "primaryServer": "stun.l.google.com",
    "primaryPort": 19302,
    "secondaryServer": "stun1.l.google.com",
    "secondaryPort": 19302,
    "timeoutSeconds": 5
  }
}
```

The same values can come from a JSON file or string, loaded straight into the
sector:

```dart
ConfigManagerSingleton().loadFromJson('stun.json', sector: stunConfigSector);
```

Explicit constructor arguments always win over the configured defaults, and
`initStunConfig()` with no argument restores the built-in ones.

### Named configurations

The package ships a few ready-made alternatives. None of them is active until
you select it:

| Preset | Servers | Use it when |
| --- | --- | --- |
| `chinaStunConfig` | `stun.miwifi.com` (Xiaomi) + `stun.chat.bilibili.com` | The default Google servers are blocked by the Great Firewall |
| `cloudflareStunConfig` | `stun.cloudflare.com` + Google as NAT secondary | You would rather not depend on Google for the main request path |
| `europeStunConfig` | `stun.nextcloud.com:443` + `stun.sipgate.net` | You want EU-hosted servers, or a primary on port 443 to get through HTTPS-only firewalls |

```dart
initStunConfig(chinaStunConfig);  // by value
useStunConfig('china');           // by name
```

Each preset pairs its NAT-detector primary and secondary across two
independent operators, because RFC 5780 Test 3 (and its secondary-server
fallback, see [NAT Type Detection](#nat-type-detection) below) needs the
secondary to resolve to a different IP than the primary.

#### Registering your own

Your application can put its own configurations next to the built-in ones and
then pick any of them at runtime from a single string — an environment
variable, a CLI flag, a field in your own config file:

```dart
registerStunConfig('acme', {
  'server': {'address': 'stun.acme.internal', 'port': 3478},
  'timeoutSeconds': 2,
});

useStunConfig(Platform.environment['STUN_PRESET'] ?? 'acme');
```

Registering does not apply anything; only `useStunConfig` does. Reusing a name
replaces that entry, so you can also re-tune a built-in preset under your own
name.

| | |
| --- | --- |
| `registerStunConfig(name, config)` | Add (or replace) a named configuration |
| `unregisterStunConfig(name)` | Remove one; returns it, or `null` if absent |
| `useStunConfig(name, {overrides})` | Apply it, with optional ad-hoc overrides merged on top |
| `stunConfigNamed(name)` | Tolerant lookup: `null` for an unknown or `null` name |
| `stunConfigNames` / `stunConfigPresets` | What is available (read-only) |
| `resetStunConfigPresets()` | Drop every custom registration |

`useStunConfig` throws an `ArgumentError` listing the available names when it
does not recognise one, so a typo in a deployment variable fails at startup
instead of silently falling back to servers that may be unreachable from where
the app runs. When you want the opposite — an unset variable meaning "just use
the defaults" — go through the tolerant lookup, which `initStunConfig` accepts
as `null`:

```dart
initStunConfig(stunConfigNamed(Platform.environment['STUN_PRESET']));
```

Your own classes can read the same defaults by mixing in `StunConfigExtension`
on top of `ConfigExtension`, which pins the sector and exposes the values
already coerced to their Dart types:

```dart
class MyProbe with ConfigExtension, StunConfigExtension {
  MyProbe({String? address}) {
    // Resolve in the body: the getters are instance members, so they are not
    // available in an initializer list.
    _address = address ?? defaultStunAddress;
  }

  late final String _address;
}
```

## Quick Start

### Basic STUN Request

```dart
import 'package:stun/stun.dart';

void main() async {
  // Internal socket management — binds and owns the socket for you.
  final handler = await StunHandler.withoutSocket(
    address: 'stun.l.google.com',
    port: 19302,
  );

  try {
    final response = await handler.performStunRequest();

    print('Public IP: ${response.publicIp(handler.getIpVersion())}');
    print('Public Port: ${response.publicPort(handler.getIpVersion())}');
  } finally {
    handler.close();
  }
}
```

You can also bring your own socket, for external ownership:

```dart
import 'dart:io';
import 'package:stun/stun.dart';

final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
final handler = StunHandler(socket, address: 'stun.l.google.com', port: 19302);
```

### IPv6 / IPv4 selection

```dart
// IPv6 (default)
final ipv6Handler = await StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  type: InternetAddressType.IPv6,
);

// IPv4 companion
final ipv4Handler = await StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  type: InternetAddressType.IPv4,
);
```

### NAT Type Detection

Detect the type of NAT you're behind and understand your network connectivity:

```dart
import 'package:stun/stun.dart';

void main() async {
  // Binds its own IPv4 socket and uses the configured STUN defaults
  // (primary + optional secondary server for symmetric-NAT detection).
  final detector = await NATDetector.withDefaults();

  try {
    final result = await detector.detectNATType();

    print('NAT Type: ${result.natType.displayName}');
    print('Filtering: ${result.filteringBehavior.displayName}');
    print('Mapping: ${result.mappingBehavior.displayName}');
    print('Public IP: ${result.publicIp}:${result.publicPort}');
    print('RFC 5780 Support: ${result.rfc5780Supported}');
    print('Detection Time: ${result.detectionTime.inMilliseconds}ms');
  } finally {
    detector.socket.close();
  }
}
```

`NATDetector`'s regular constructor takes an explicit socket (and optional
`primaryServer`/`primaryPort`/`secondaryServer`/`secondaryPort`/`timeout`,
falling back to the STUN config when omitted) if you need more control than
`withDefaults()` gives you:

```dart
final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
final detector = NATDetector(
  primaryServer: 'stun.l.google.com',
  primaryPort: 19302,
  socket: socket,
  secondaryServer: 'stun1.l.google.com', // Test 3 fallback when the primary
  secondaryPort: 19302,                  // doesn't advertise an alternate address
);
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

### Get Local Network Information

```dart
// Get local IP and port without contacting a STUN server
final localInfo = await handler.performLocalRequest();

print('Local IPv4: ${localInfo.localIpv4}:${localInfo.localPortIpv4}');
print('Local IPv6: ${localInfo.localIpv6}:${localInfo.localPortIpv6}');
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

## Dual-Stack Handlers

`DualStunHandler` runs IPv4 and IPv6 STUN requests in parallel and merges the
results. Either family can be missing — at least one must be present, and
`IDualStunHandler`'s family-defaulted methods (`getHandler()`, `getSocket()`,
`close()`, …) target **IPv6** when `type` is omitted.

```dart
import 'package:stun/stun.dart';

final dual = DualStunHandler();
dual.setIpv4Handler(await StunHandler.withoutSocket(type: InternetAddressType.IPv4));
dual.setIpv6Handler(await StunHandler.withoutSocket(type: InternetAddressType.IPv6));

final response = await dual.performStunRequest(); // both families, in parallel
print(response.publicIp(InternetAddressType.IPv4));
print(response.publicIp(InternetAddressType.IPv6));

dual.setStunServer('stun1.l.google.com', 19302); // both families
dual.setStunServer('stun1.l.google.com', 19302, type: InternetAddressType.IPv4); // one family only

dual.close(); // closes and clears both
```

A handler failing on one family (e.g. a `SocketException`) doesn't fail the
whole request — its slot is simply `null` in the merged response.
`StateError` is only thrown when **both** families fail or are missing.

### Global Singleton

`DualStunHandlerSingleton` is a real module-level singleton (`.instance` and
the default constructor both return the same object) that builds its own
IPv4/IPv6 handlers on `initialize()`:

```dart
import 'package:stun/stun.dart';

void main() async {
  await DualStunHandlerSingleton.instance.initialize(
    address: 'stun.l.google.com',
    port: 19302,
    timeout: const Duration(seconds: 5),
  );

  final response = await DualStunHandlerSingleton.instance.performStunRequest();
  print(response.publicIp(InternetAddressType.IPv6));

  // Replace just one family
  final newIpv6 = await StunHandler.withoutSocket(
    address: 'stun1.l.google.com',
    port: 19302,
    type: InternetAddressType.IPv6,
  );
  DualStunHandlerSingleton.instance.replaceHandler(newIpv6, type: InternetAddressType.IPv6);

  print(DualStunHandlerSingleton.instance.ipv4LastStunUpdated);
  print(DualStunHandlerSingleton.instance.lastStunUpdated); // later of ipv4/ipv6

  DualStunHandlerSingleton.instance.close();
}
```

`initialize()` swallows a bind failure on either family individually and only
throws `StateError` if **both** IPv4 and IPv6 fail to initialize.

## Dependency Injection

The package integrates with [`singleton_manager`](https://pub.dev/packages/singleton_manager):
every injectable class (`StunHandler`, `StunHandlerMigratable`,
`DualStunHandler`, `DualStunHandlerMigratable`) is annotated
`@dependencyInjectable`, and `packages/Stun/lib/src/main_injection.dart` is
generated by `singleton_manager_generator` to connect them all to
`RegistryManager.instance`.

Because a plain `RawDatagramSocket` isn't itself `@dependencyInjectable`,
resolving a handler from an empty registry throws `RegistryNotFoundError` —
`DualStunInjector` closes that gap by binding a real IPv4/IPv6 socket pair and
registering them under the `'ipv4'`/`'ipv6'` subkeys before the rest of the
graph connects:

```dart
import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';

const injector = DualStunInjector();

Future<void> main() async {
  const key = 'my-app';
  await injector.registerAllSingletonsStunAsync(key: key);

  final dual = RegistryManager.instance.getInstance<IDualStunHandler>(key: key);
  final ipv4 = RegistryManager.instance.getInstance<IStunHandler>(key: key, subkey: 'ipv4');
  final ipv6 = RegistryManager.instance.getInstance<IStunHandler>(key: key, subkey: 'ipv6');

  final response = await dual.performStunRequest();
  print(response.publicIp(InternetAddressType.IPv6));

  dual.close();
}
```

A registered `IStunHandler` and its `IStunHandlerMigratable` counterpart under
the same `(key, subkey)` resolve to the **same underlying socket** — they are
two views of the same endpoint. Registering under a different `key` builds a
fully independent graph, letting an app run several STUN stacks side by side.

DI-resolved handlers always use the STUN config defaults for the server
address/port; call `setStunServer` on the resolved instance afterwards for a
custom one, or construct the class directly instead of going through the
registry if the server needs to be known at construction time.

### Migratable handlers

`StunHandlerMigratable`/`DualStunHandlerMigratable` add a `migrateTo(target)`
method that copies the live STUN server configuration onto another handler,
without ever being replaced themselves — they stay the stable source of truth
for that `(key, subkey)`:

```dart
final source = RegistryManager.instance
    .getInstance<IDualStunHandlerMigratable>(key: key);
final target = RegistryManager.instance.getInstance<IDualStunHandler>(key: key);

source.migrateTo(target); // copies both families' server config into target
source.migrateTo(target, type: InternetAddressType.IPv4); // one family only
```

### Socket migration helpers

When a socket needs to be recreated (e.g. after a network change), these
helpers rebind the plain `IStunHandler`/`RawDatagramSocket` registered for a
`(key, subkey)` onto a fresh socket, seeding the new handler's server config
from the still-live `IStunHandlerMigratable`:

```dart
import 'dart:io';
import 'package:stun/stun.dart';

// Single family, resolving the subkey from the socket's own address type
final newSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
final migratedHandler = migrateStunHandlerSocket(newSocket, key: key);

// Or let the helper bind the socket for you
final migratedIpv4 = await migrateStunHandlerSocketIpv4(key: key);
final migratedIpv6 = await migrateStunHandlerSocketIpv6(key: key);

// Batch both families atomically (validates both sockets before touching either)
final migrated = migrateDualStunHandlerSockets(
  ipv4Socket: await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0),
  ipv6Socket: await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0),
  key: key,
);
```

Only the `RawDatagramSocket`/`IStunHandler` registry entries are swapped; the
registered `IStunHandlerMigratable`/`IDualStunHandlerMigratable` is never
replaced.

## API Reference

### `NATDetector` Class

Detect NAT type using the RFC 5780 algorithm:

```dart
class NATDetector {
  NATDetector({
    String? primaryServer,      // falls back to STUN config
    int? primaryPort,           // falls back to STUN config
    required RawDatagramSocket socket,
    String? secondaryServer,    // Test 3 fallback, RFC 5780/3489-less servers
    int? secondaryPort,
    Duration? timeout,          // falls back to STUN config
    void Function(String)? onLog,
  });

  static Future<NATDetector> withDefaults(); // self-bound IPv4 socket + STUN config defaults

  Future<NATDetectionResult> detectNATType();
}
```

### `NATDetectionResult` Type

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

### `IStunHandlerBase` / `IStunHandler` Interfaces

```dart
abstract class IStunHandlerBase {
  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();
  Future<bool> pingStunServer();
  void setStunServer(String address, int port);
  void close();
  DateTime? get lastStunUpdated;
  DateTime? get lastLocalUpdated;
  RawDatagramSocket getSocket();
}

abstract class IStunHandler implements IStunHandlerBase {
  InternetAddressType getIpVersion();
}
```

### `IDualStunHandler` Interface

```dart
abstract class IDualStunHandler implements IStunHandlerBase {
  Future<void> initializeWithHandlers(IStunHandler first, {IStunHandler? second});
  IStunHandler? getHandler({InternetAddressType type = InternetAddressType.IPv6});
  void setHandler(IStunHandler handler, {InternetAddressType type = InternetAddressType.IPv6});
  void clearHandler({InternetAddressType type = InternetAddressType.IPv6});
  void replaceHandler(IStunHandler handler, {InternetAddressType type = InternetAddressType.IPv6});
  @override RawDatagramSocket getSocket({InternetAddressType type = InternetAddressType.IPv6});
  @override void setStunServer(String address, int port, {InternetAddressType? type});
  @override void close({InternetAddressType? type});
  DateTime? getLastStunUpdated({InternetAddressType type = InternetAddressType.IPv6});
  DateTime? getLastLocalUpdated({InternetAddressType type = InternetAddressType.IPv6});
  IStunHandler? get ipv4Handler;
  IStunHandler? get ipv6Handler;
}
```

Concrete dual handlers (`DualStunHandler`, `DualStunHandlerBase`,
`DualStunHandlerSingleton`, `DualStunHandlerMigratable`) additionally expose
`setIpv4Handler`/`setIpv6Handler`/`clearIpv4Handler`/`clearIpv6Handler`,
`pingStunServer({type})`, and `lastStunUpdated`/`lastLocalUpdated` merged
across both families.

### `StunResponse` Type

Per-family response from a STUN request — every accessor takes the
`InternetAddressType` you want:

```dart
class StunResponse {
  String? publicIp(InternetAddressType type);
  int? publicPort(InternetAddressType type);
  Uint8List? transactionId(InternetAddressType type);
  Uint8List? raw(InternetAddressType type);
  Map<String, dynamic>? attrs(InternetAddressType type);
}
```

### `LocalInfo` Type

```dart
class LocalInfo {
  String? localIpv4;
  int? localPortIpv4;
  String? localIpv6;
  int? localPortIpv6;
}
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
- `stun.cloudflare.com:3478`
- `stun.nextcloud.com:443`
- `stun.sipgate.net:3478`

## Testing

Run the comprehensive test suite:

```bash
cd packages/StunDartTests
dart test
```

The test suite covers dual-stack management (singleton, fallback, socket
migration), NAT type detection and its secondary-server fallback, STUN
message parsing and encoding, config presets and deep-merge behavior, the
DI/registry wiring, and IPv4/IPv6 connectivity.

**Total: 239 tests - All passing ✅**

## Architecture

StunDart follows a clean architecture with separation of concerns:

```
packages/Stun/lib/
├── stun.dart                      # Public barrel (generated by index_generator)
└── src/
    ├── types/                     # Records, enums (StunResponse, LocalInfo, NATType, …)
    ├── config/                    # stun_config, presets, protocol constants
    ├── interfaces/
    │   ├── single/                # IStunHandler(Base|Migratable|Profile)
    │   └── dual/                  # IDualStunHandler(Migratable|Profile|Singleton)
    ├── implementations/
    │   ├── single/                # StunHandler, StunHandlerMigratable, StunHandlerProfile,
    │   │                          #   StunMessage, StunRequestHandler, StunSocketManager
    │   └── dual/                  # DualStunHandler, DualStunHandlerBase, DualStunHandlerSingleton,
    │                              #   DualStunHandlerMigratable, DualStunHandlerProfile,
    │                              #   HandlerFactory, SingletonHandlerFactory
    ├── mixins/                    # Shared logic behind the implementations above
    │   ├── single/                # StunHandlerMixin, StunMessageMixin, StunLoggerMixin, …
    │   └── dual/                  # DualStunHandlerMixin, HandlerSelectorMixin, …
    ├── nat/                       # NATDetector + NatDetectorMixin
    ├── migration/                 # Socket migration helpers
    ├── factories/                 # DI socket wiring (DualStunInjector)
    └── main_injection.dart        # Generated singleton_manager registry wiring
```

### Developer Tooling

The `stun.dart` barrel file is auto-generated by [`index_generator`](https://pub.dev/packages/index_generator). After adding new public files, regenerate it with:

```bash
melos run barrels
```

`packages/Stun/lib/src/main_injection.dart` is generated by
[`singleton_manager_generator`](https://pub.dev/packages/singleton_manager_generator)
and connects every `@dependencyInjectable` class to `RegistryManager.instance`.
Regenerate it after adding/removing a DI-annotated class:

```bash
melos run registry
```

Both scripts are defined in the workspace root `pubspec.yaml` under `melos.scripts`.

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
- **IP Support:** IPv4 and/or IPv6 (IPv6 preferred)

## Performance

- Basic STUN request: < 100ms (typical)
- NAT type detection: 2-10 seconds (4 sequential tests)
- Memory efficient: Minimal allocations
- No external dependencies beyond `config_manager`, `singleton_manager`, and `callback_handler`

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
