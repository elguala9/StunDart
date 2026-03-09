# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - Unreleased

### Added 🎉
- **StunHandlerSingleton**: Global instance management for StunHandler
  - `StunHandlerSingleton.instance` for accessing the singleton
  - `createNewHandler()` to create and set a new internal handler
  - `replaceHandler(IStunHandler)` to replace with custom implementation
  - Full delegation to IStunHandler interface

- **StunHandler.withoutSocket()**: Factory constructor for internal socket management
  - Eagerly creates and manages UDP socket internally
  - No need for external socket ownership
  - Simplified API for socket management
  - Support for IPv4 and IPv6

- **Performance Optimization: Response Caching** 🚀
  - Public IP/port responses are cached after first STUN request
  - Local IP/port information is cached (immutable with same socket)
  - Eliminates redundant network calls for repeated requests on same handler
  - Cache automatically invalidates when socket is recreated
  - Significantly improves performance for applications making multiple STUN queries

- **Enhanced Test Coverage**:
  - 8 tests for StunHandler.withoutSocket() factory pattern
  - 6 new comprehensive caching behavior tests:
    - STUN response caching on repeated requests
    - Local info caching on repeated requests
    - Cache invalidation on socket recreation
    - Cache behavior with server changes
    - Combined cache reset scenarios
  - Total test count: 105 passing tests (was 99)

### Changed
- Architecture improvements for better socket lifecycle management
- Updated examples showing singleton and internal socket patterns

## [1.1.0] - 2025-01-30

### Added 🎉
- **NAT Type Detection**: Complete RFC 5780 NAT Behavior Discovery implementation
  - `NATDetector` class for automatic NAT type identification
  - Support for 7 NAT types: Open Internet, Full Cone, Restricted Cone, Port Restricted Cone, Symmetric, Symmetric Firewall, UDP Blocked
  - Filtering behavior detection (endpoint-independent, address-dependent, address+port-dependent)
  - Mapping behavior analysis
  - Detailed diagnostic information with test results
  - RFC 5780 and RFC 3489 server compatibility

- **New STUN Attributes**:
  - CHANGE-REQUEST (0x0003) for requesting alternate server responses
  - CHANGED-ADDRESS (0x0005) for legacy RFC 3489 support
  - RESPONSE-ORIGIN (0x802b) for response source verification
  - OTHER-ADDRESS (0x802c) for alternate server discovery

- **New Types and Enums**:
  - `NATType` enum with 7 NAT classifications
  - `NATFilteringBehavior` enum for filtering analysis
  - `NATMappingBehavior` enum for mapping analysis
  - `NATDetectionResult` typedef with complete detection information

- **Enhanced Testing**:
  - 58+ comprehensive tests (16 enum tests, 24 message tests, 18 integration tests)
  - NAT detection integration tests
  - Multiple STUN server validation tests
  - Edge case and error handling tests

- **Documentation**:
  - Complete API documentation for all new classes
  - NAT type comparison table
  - Multiple examples for NAT detection
  - Detailed usage guides
  - P2P capability recommendations

### Changed
- Enhanced `StunMessage` class with new factory method `createBindingRequestWithChangeRequest()`
- Improved README with NAT detection examples and comprehensive feature list
- Updated pubspec.yaml with topics and platform support
- Better error messages and diagnostic output

### Technical Details
- Implements RFC 5780 four-test algorithm for accurate NAT detection
- Broadcast stream support for multiple concurrent STUN requests
- Configurable timeout support for each test
- Graceful fallback to RFC 3489 for legacy servers

### Migration Guide
```dart
// Old: Basic STUN request only
final response = await handler.performStunRequest();
print('Public IP: ${response.publicIp}');

// New: With NAT detection
final detector = NATDetector(
  primaryServer: 'stun.l.google.com',
  primaryPort: 19302,
  socket: socket,
);
final result = await detector.detectNATType();
print('NAT Type: ${result.natType.displayName}');
print('Public IP: ${result.publicIp}');
```

## [1.0.1] - 2025-01-30

### Fixed
- Complete LGPL v3 license text
- Code formatting issues
- Import paths in implementation files

### Added
- Comprehensive example in example/example.dart

### Changed
- Renamed library from stundart to stun for consistency

## [1.0.0] - 2025-01-30

### Added
- Initial release
- RFC 5389 compliant STUN protocol implementation
- IPv4 and IPv6 dual-stack support
- STUN Binding Request/Response with XOR-MAPPED-ADDRESS
- Clean interface-based architecture
- Record types for type safety
- Configurable STUN servers and timeouts
- Comprehensive test suite with 11 passing tests
- Support for NAT discovery and public IP resolution
- Local network information retrieval
- STUN server ping functionality
- Example implementations

[1.1.0]: https://github.com/elguala9/StunDart/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/elguala9/StunDart/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/elguala9/StunDart/releases/tag/v1.0.0
