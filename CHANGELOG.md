# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-03-30

### Added
- `IDualStunHandlerBase` interface: full public contract for `DualStunHandlerBase`, extends `IValueForRegistry`
- `RegistryAccess` initial point: named multi-instance STUN registration via string keys
- Shared `stun_builder.dart` helper: common socket-wiring logic for both initial-point variants

### Changed
- `DualStunHandlerBase` implements `IDualStunHandlerBase` + `ValueForRegistry`, adds `destroy()`
- Initial-point code uses interfaces throughout (no concrete type leakage)

### Tests
- 198 tests passing ✅

## [1.4.2] - 2026-03-30

### Changed
- Updated `singleton_manager` dependency from `^0.5.0` to `^0.6.1`

## [1.2.2] - 2026-03-14

### Added
- **Dependency Injection Support**: Implemented `ISingletonStandardDI` interface compliance
  - `initializeDI()` method for DI container registration
  - Full support for `SingletonDIAccess` and `SingletonDI` patterns
  - Proper factory registration and singleton management
- **Resource Cleanup**: Added `destroy()` method to all handler classes
  - Implements `IValueForRegistry` interface requirement
  - Proper cleanup of socket resources on destruction
- **DualStunHandler Class**: New handler for managing IPv4/IPv6 simultaneously
  - Parallel request execution on both protocols
  - IPv6-preferred result selection
  - Implements `IDualStunHandler` interface

### Changed
- Updated test suite: 161 passing tests (was 157)
- Enhanced README with DI and callback support features

### Technical Details
- `SingletonHandlerFactory.initializeDI()` - registers factory in DI container
- `DualStunHandlerSingleton.initializeDI()` - initializes complete DI setup for singleton pattern
- `DualStunHandler.initializeDI()` - registers dual handler in DI container
- All handlers implement proper `destroy()` for resource cleanup

## [1.2.1] - 2025-02-XX

### Added
- Last updated timestamps for STUN and local requests
  - `lastStunUpdated` - timestamp of last successful STUN request
  - `lastLocalUpdated` - timestamp of last successful local request
  - Per-handler and singleton-level timestamp tracking
  - IPv4/IPv6 specific timestamps in singleton

## [1.5.1] - LEGACY (v1.5.x branch)

### Added
- Typed socket refresh callbacks for IPv4/IPv6
  - `setOnSocketRefreshIpv4()` - IPv4-specific callbacks
  - `setOnSocketRefreshIpv6()` - IPv6-specific callbacks
  - Socket type validation for proper callback registration

## [1.5.0] - LEGACY (v1.5.x branch)

### Added
- Socket refresh callbacks on handler recreation
  - Fires when socket is recreated due to network errors
  - Provides old and new responses for state reconciliation

## [1.2.0] - Earlier

### Added
- Core STUN implementation (RFC 5389/5780)
- Dual-stack IPv4/IPv6 support
- NAT type detection with 7 result types
- Response caching for performance
- Singleton pattern for global instance management
- Flexible socket management options
- Comprehensive test coverage
