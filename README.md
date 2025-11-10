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

## Workspace Features

This monorepo uses Dart's workspace feature to manage multiple packages:

- Shared dependencies across packages
- Unified version management
- Centralized linting configuration
- Local package references

## Contributing

1. Make changes in the appropriate package
2. Run tests to ensure nothing breaks
3. Follow the linting rules defined in `analysis_options.yaml`

## License

TBD
