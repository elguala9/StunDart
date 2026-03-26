# Changelog

All notable changes to the StunDart project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.4.1] - 2026-03-26

### Changed
- Updated `singleton_manager` dependency from `^0.4.0` to `^0.5.0`
- Updated `singleton_manager_generator` dev dependency from `^1.0.4` to `^1.2.0`

## [1.4.0] - 2026-03-21

### Added
- **`StunHandlerBase` now part of public API**: Base class for DI-based singleton integrations is now exported from `stun.dart`
- **`IDualCallbackHandler` now part of public API**: Interface for managing IPv4/IPv6 socket refresh callbacks is now exported from `stun.dart`
- **`index_generator` tooling**: Barrel file (`stun.dart`) is now auto-generated via `index_generator`
  - Run `melos run barrels` to regenerate the barrel file after adding new public symbols
  - Configuration in `pubspec.yaml` under `index_generator:` key

### Fixed
- **Circular import in `stun_handler_base.dart`**: Replaced `import 'package:stun/stun.dart'` with direct relative imports, enabling `StunHandlerBase` to be safely exported from the public barrel

### Tooling
- Added `melos run barrels` script that runs `index_generator` across all packages (excluding test packages)
- `stun.dart` barrel is now regenerated automatically — no more manual export management

### Tests
- 177 tests passing ✅

## [1.2.1] - 2026-03-10

### Added
- **Socket Refresh Callbacks**: StunHandler and StunHandlerSingleton now support callbacks when socket is recreated after network errors
  - `CallbackHandler` typedef for StunHandler callbacks
  - `SingletonCallbackHandler` typedef for singleton callbacks with IPv4/IPv6 identification
  - All constructors accept `onSocketRefresh` parameter

### Changed
- Improved socket error handling with callback support
- Enhanced code organization with modular directory structure

### Improved
- Code quality and maintainability through aggressive modularization (<200 lines per core file)
- Better separation of concerns with dedicated modules for socket management, factories, and request handling

### Tests
- 172 tests passing (includes 9 new socket refresh callback tests)
- Full coverage of callback lifecycle and dual-stack behavior

## [1.3.0] - 2026-03-09

### Added
- **New `IStunHandlerSingleton` Interface**: Formal interface defining the contract for singleton with full feature support (timeout, logging, dual IPv4/IPv6)
- **Configurable Timeout**: StunHandler and StunHandlerSingleton now accept custom `Duration timeout` parameter (default: 5 seconds)
- **Logging Support**: StunHandler and StunHandlerSingleton accept `void Function(String)? onLog` callback for tracking STUN operations
- **IPv6 Local IP Fix**: `performLocalRequest()` now correctly returns IPv4 addresses in dotted format and IPv6 addresses in colon format

### Changed
- `StunHandlerSingleton.initialize()` now accepts `timeout` and `onLog` parameters
- All STUN operations now propagate timeout and logging configurations to handlers
- Replaced all `print()` calls with configurable logging callbacks

### Improved
- Better error messages including timeout duration in timeout exceptions
- IPv6 address handling respects IP version type
- Added `@override` annotations for all interface method implementations (code quality)

### Tests
- 123 tests passing (all tests)
- 6 new timeout and logging tests
- IPv6 local IP format tests
- IStunHandlerSingleton interface contract tests

## [1.2.0] - 2026-03-04

### Added
- **Dual-Stack StunHandlerSingleton**: Manages both IPv4 and IPv6 STUN handlers simultaneously
- Parallel execution of STUN requests on both handlers for improved reliability
- IPv6-first preference in singleton (returns IPv6 result if available, falls back to IPv4)
- Individual handler access and replacement capabilities

### Changed
- StunHandlerSingleton now implements structured dual-handler management
- Handler initialization creates IPv4 (always) and IPv6 (gracefully) handlers

### Tests
- Added 24 comprehensive tests for StunHandlerSingleton functionality

## [1.1.0] - 2025-12-15

### Added
- **Response Caching**: StunHandler now caches both STUN responses and local network information
- Automatic cache invalidation on socket recreation
- Cache consistency across multiple requests to same handler

### Changed
- Improved performance by eliminating redundant network requests
- Cache behavior documented with test coverage

### Tests
- Added 6 cache behavior tests

## [1.0.0] - 2025-11-20

### Added
- **Complete STUN Protocol Implementation**
  - RFC 5389 compliant STUN Binding Request/Response
  - RFC 5780 NAT Behavior Discovery support
  - RFC 3489 legacy server compatibility
  - XOR-MAPPED-ADDRESS attribute support
  - Magic cookie validation and transaction ID tracking

- **NAT Type Detection**
  - 7 NAT types supported (Open Internet, Full Cone, Restricted Cone, etc.)
  - Filtering behavior detection (endpoint-independent, address-dependent, address+port-dependent)
  - Mapping behavior analysis
  - Detailed diagnostic information
  - RFC 5780 and RFC 3489 server support

- **Dual Stack Support**
  - Full IPv4 support
  - Full IPv6 support
  - Automatic IP version detection
  - Dual-stack compatibility testing

- **Flexible API**
  - Clean interface-based design (`IStunHandler`)
  - Type-safe record types
  - Async/await API
  - Multiple STUN server support
  - Two constructor patterns for StunHandler

- **Comprehensive Documentation**
  - API reference with examples
  - NAT type explanation tables
  - Public STUN server list
  - Example code for common use cases
  - Architecture overview

### Tests
- 97 comprehensive tests covering all features
- STUN message parsing tests
- NAT detection tests
- IPv4/IPv6 connectivity tests
- Integration tests with public STUN servers

---

**Full Commits:**
- [v1.4.1](https://github.com/elguala9/StunDart/releases/tag/v1.4.1) - Dependency updates: singleton_manager ^0.5.0, singleton_manager_generator ^1.2.0
- [v1.4.0](https://github.com/elguala9/StunDart/releases/tag/v1.4.0) - Public API expansion, circular import fix, index_generator tooling
- [v1.3.0](https://github.com/elguala9/StunDart/releases/tag/v1.3.0) - Enhanced with timeout, logging, and formal singleton interface
- [v1.2.0](https://github.com/elguala9/StunDart/releases/tag/v1.2.0) - Dual-stack singleton management
- [v1.1.0](https://github.com/elguala9/StunDart/releases/tag/v1.1.0) - Response caching
- [v1.0.0](https://github.com/elguala9/StunDart/releases/tag/v1.0.0) - Initial release

## Upgrade Guide

### Upgrading from 1.4.0 to 1.4.1

**Breaking Changes:** None — dependency-only update, no API changes

### Upgrading from 1.3.0 to 1.4.0

**Breaking Changes:** None — fully backward compatible

**New Public Symbols:**
```dart
// StunHandlerBase and IDualCallbackHandler are now importable directly
import 'package:stun/stun.dart';

// Use IDualCallbackHandler for custom callback wiring
final callbacks = DualCallbackHandler();
callbacks.registerIpv4((data) => print('IPv4 refresh: ${data.$1.publicIp}'));
callbacks.registerIpv6((data) => print('IPv6 refresh: ${data.$1.publicIp}'));

// Or subclass StunHandlerBase for custom DI integration
class MyStunSingleton extends StunHandlerBase { ... }
```

**Developer Tooling:**
```bash
# Regenerate barrel file (stun.dart) after adding new public files
melos run barrels
```

### Upgrading from 1.2.0 to 1.2.1

**Breaking Changes:** None - fully backward compatible

**New Features (Optional):**
```dart
// Add socket refresh callback to track socket recreation
final handler = await StunHandler.withoutSocket(
  address: 'stun.l.google.com',
  port: 19302,
  onSocketRefresh: (newResponse, oldResponse) {
    print('Socket was recreated, new public IP: ${newResponse.publicIp}');
  },
);

// Or with singleton
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
  onSocketRefresh: (newResponse, oldResponse, ipv6: bool) {
    print('${ipv6 ? "IPv6" : "IPv4"} socket refreshed');
  },
);
```

### Upgrading from 1.2.0 to 1.3.0

**Breaking Changes:** None

**New Features:**
```dart
// Use new timeout configuration
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
  timeout: const Duration(seconds: 15),  // NEW
);

// Enable logging
await StunHandlerSingleton.instance.initialize(
  address: 'stun.l.google.com',
  port: 19302,
  onLog: (msg) => print('STUN: $msg'),  // NEW
);

// Use new interface for DI
final singleton = StunHandlerSingleton.instance as IStunHandlerSingleton;
```

### Upgrading from 1.1.0 to 1.2.0

**Breaking Changes:** None - fully backward compatible

**Migration Path:**
Existing code using `StunHandlerSingleton` will automatically benefit from dual-stack support without changes. IPv6 handler creation fails gracefully if unavailable.

### Upgrading from 1.0.0 to 1.1.0

**Breaking Changes:** None

The caching feature is transparent to existing code and provides automatic performance improvements.
