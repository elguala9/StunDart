# StunDart Monorepo

A Dart monorepo workspace for STUN (Session Traversal Utilities for NAT) protocol implementation.

## Structure

This monorepo contains the following packages:

```
StunDart/
├── packages/
│   ├── StunDart/          # Main StunDart library
│   └── StunDartTests/     # Test suite for StunDart
├── pubspec.yaml           # Workspace configuration
└── analysis_options.yaml  # Shared linting rules
```

## Packages

### StunDart

The main STUN protocol implementation library.

- **Location**: `packages/StunDart`
- **Purpose**: Core STUN protocol functionality

### StunDartTests

Comprehensive test suite for the StunDart package.

- **Location**: `packages/StunDartTests`
- **Purpose**: Unit and integration tests

## Getting Started

### Prerequisites

- Dart SDK 3.0.0 or higher

### Installation

1. Clone the repository
2. Install dependencies for all packages:

```bash
dart pub get
```

### Development

Navigate to individual packages to work on them:

```bash
cd packages/StunDart
dart pub get
```

### Running Tests

From the root directory:

```bash
cd packages/StunDartTests
dart test
```

## Key Features

- **RFC 5389 & 5780 Compliant**: Full STUN protocol implementation
- **Dual-stack Support**: IPv4 and IPv6
- **NAT Detection**: Complete RFC 5780 NAT type detection (7 types, filtering & mapping behaviors)
- **Performance**: Response caching eliminates redundant network calls
- **Singleton Pattern**: Global instance management via `StunHandlerSingleton`
- **Flexible Socket Management**: Internal socket management with `StunHandler.withoutSocket()` or external socket ownership
- **Zero Dependencies**: Pure Dart implementation
- **Comprehensive Testing**: 105+ passing tests with full coverage

## Workspace Features

This monorepo uses Dart's workspace feature to manage multiple packages:

- Shared dependencies across packages
- Unified version management
- Centralized linting configuration
- Local package references

## Performance Optimization

The StunDart library includes automatic response caching to optimize performance:

- **Public IP/Port Caching**: Cached after first STUN request, eliminating redundant network calls
- **Local Address Caching**: Local IP/port information is cached (doesn't change with same socket)
- **Automatic Invalidation**: Cache is automatically invalidated when socket is recreated

This means repeated calls to `performStunRequest()` or `performLocalRequest()` on the same handler instance have minimal overhead.

```dart
final handler = await StunHandler.withoutSocket();

// First call: Makes actual STUN request
final response1 = await handler.performStunRequest(); // ~100-500ms

// Second call: Returns cached response (instant)
final response2 = await handler.performStunRequest(); // <1ms

// Socket recreation triggers cache invalidation
handler.getSocket().close(); // Simulates error
final response3 = await handler.performStunRequest(); // New STUN request made, cache reset
```

## Contributing

1. Make changes in the appropriate package
2. Run tests to ensure nothing breaks
3. Follow the linting rules defined in `analysis_options.yaml`

## License

TBD
