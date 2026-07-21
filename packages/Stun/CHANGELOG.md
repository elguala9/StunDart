# Changelog

All notable changes to the StunDart project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Optional secondary server for NAT detection**: `NATDetector` now accepts `secondaryServer`/`secondaryPort`. When the primary STUN server does not advertise an alternate address (OTHER-ADDRESS/CHANGED-ADDRESS), Test 3 falls back to the secondary server, enabling symmetric NAT detection against servers without RFC 5780/3489 support (e.g. Google STUN). Test 3 fails explicitly if the secondary server resolves to the same endpoint as the primary.
- **`NATDetector.withDefaults()`**: zero-argument async factory that binds its own IPv4 socket and uses the constant defaults from `defaultNatDetectorConfig` (Google STUN primary + secondary, 5s timeout). The caller closes the socket via `detector.socket.close()`.

## [1.6.1] - 2026-07-15

### Changed
- **Internal refactor into mixins** (`src/mixins/`): shared logic extracted from `StunHandler`, `DualStunHandler`, `NATDetector`, `StunMessage`, `StunHandlerBase`, `HandlerFactory`, and `StunSocketManager` into reusable mixins (`StunHandlerMixin`, `DualStunHandlerMixin`, `NatDetectorMixin`, `StunMessageMixin`, `StunHandlerBaseMixin`, `HandlerFactoryMixin`, `HandlerSelectorMixin`, `StunServerResolverMixin`, `StunLoggerMixin`, `DestroyableHandlerMixin`). No public API changes — fully backward compatible.

### Tests
- 223 tests passing ✅

## [1.6.0] - 2026-07-11

### Added
- **IPv4 is now optional**: `DualStunHandler` and `StunHandlerBase`/`Singleton` accept a nullable IPv4 handler, symmetric to IPv6. At least one of the two must be present; either one alone is sufficient.
- **`IDualHandlerFacade`** (`interfaces/i_dual_handler_facade.dart`): internal shared contract factored out of `IDualStunHandler` and `IStunHandlerBase` to avoid redeclaring the same members in both.
- `clearIpv4Handler()` / `clearIpv6Handler()` to explicitly remove a handler.

### Changed
- `replaceHandler()`/`setStunServer()`/`close()` and related APIs updated to handle a possibly-null IPv4 or IPv6 handler consistently.

### Tests
- Expanded coverage for optional-IPv4 and handler-clearing scenarios in `dual_stun_handler_fallback_test.dart` and `stun_handler_singleton_test.dart`.

## [1.5.1] - 2026-04-11

### Fixed
- **Dual-stack fallback in `DualStunHandler`**: `performStunRequest()` and `performLocalRequest()` now correctly fall back to IPv4 when IPv6 fails. Previously, `Future.wait(eagerError: false)` waited for both futures but still threw if IPv6 failed, discarding a successful IPv4 result. IPv6 failures are now treated as non-fatal via `catchError`, and the method returns the IPv4 result as fallback.

### Tests
- 198 tests passing ✅

## [1.5.0] - 2026-03-30

### Added
- **`IStunHandlerBase` interface** (`interfaces/i_stun_handler_base.dart`): Full public contract for `StunHandlerBase`, extends `IValueForRegistry` to enable `RegistryAccess` registration
- **`RegistryAccess` initial point** (`initial_point/initial_point_registry.dart`): Named multi-instance support via string keys
  - `initialPointStunWithSocketsRegistry(key, ipv4Socket, {...})` — pre-bound sockets variant
  - `initialPointStunRegistry(key, {...})` — auto-bind variant
  - Retrieve with `RegistryAccess.getInstance<IStunHandlerBase>(key)`
  - Re-registering the same key replaces the previous instance
- **`stun_builder.dart`** shared socket-wiring helper: common logic extracted from initial-point variants, returns `IDualStunHandler`/`IDualCallbackHandler` interfaces

### Changed
- `StunHandlerBase` now implements `IStunHandlerBase` and `ValueForRegistry` mixin; exposes `destroy()` (delegates to `close()`)
- `initial_point.dart` refactored to use `stun_builder.dart` and register via interfaces (`IDualStunHandler`, `IDualCallbackHandler`)
- All initial-point code uses interfaces, never concrete classes

### Tests
- 198 tests passing ✅ (+21 registry initial-point tests)

## [1.4.2] - 2026-03-30

### Changed
- Updated `singleton_manager` dependency from `^0.5.0` to `^0.6.1`

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
