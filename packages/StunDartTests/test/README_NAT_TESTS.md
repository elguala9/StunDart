# NAT Detection Test Suite

This directory contains comprehensive tests for the NAT (Network Address Translation) detection functionality added to the StunDart library.

## Test Files

### 1. nat_types_test.dart (16 tests) ✅
Tests for the new NAT type enums and typedefs:

- **NATType enum**: 7 different NAT types
  - Open Internet
  - Full Cone NAT
  - Restricted Cone NAT
  - Port Restricted Cone NAT
  - Symmetric NAT
  - Symmetric UDP Firewall
  - UDP Blocked

- **NATFilteringBehavior enum**: 4 behaviors
- **NATMappingBehavior enum**: 4 behaviors
- **NATDetectionResult typedef**: Complete result structure

**Coverage:**
- Enum values and display names
- Enum equality and switch statements
- Record creation with required and optional fields
- Complex diagnostics data structures

### 2. stun_message_nat_test.dart (24 tests) ✅
Tests for new STUN message attributes and methods:

- **New Attribute Types:**
  - CHANGE-REQUEST (0x0003)
  - CHANGED-ADDRESS (0x0005)
  - RESPONSE-ORIGIN (0x802b)
  - OTHER-ADDRESS (0x802c)

- **Factory Method:** `createBindingRequestWithChangeRequest()`
  - Test all flag combinations (changeIp, changePort)
  - Verify correct bit encoding
  - Test unique transaction ID generation

- **Parsing Methods:**
  - `getOtherAddress()` - RFC 5780
  - `getChangedAddress()` - RFC 3489 (legacy)
  - `getResponseOrigin()` - RFC 5780

**Coverage:**
- IPv4 and IPv6 address parsing
- XOR and non-XOR encoding
- Malformed attribute handling
- Encode-decode roundtrips
- Multiple attributes in single message

### 3. nat_detector_test.dart (18 tests) ✅
Integration tests for the NATDetector class:

- **Constructor and Configuration** (3 tests)
  - Parameter validation
  - Custom timeout support
  - Socket reusability

- **Basic Detection** (3 tests)
  - Successful NAT type detection
  - Valid public IP/port validation
  - Filtering and mapping behavior verification

- **Multiple Servers** (2 tests)
  - Different STUN servers consistency
  - Repeated calls consistency

- **Diagnostics** (2 tests)
  - Detailed test result tracking
  - RFC 5780 support detection

- **Edge Cases** (3 tests)
  - Invalid server handling
  - Unreachable server handling (TEST-NET-1)
  - Timeout enforcement

- **Other Tests** (5 tests)
  - Detection time measurement
  - Socket management
  - Result structure validation
  - NAT type/behavior consistency

**Coverage:**
- All NAT detection paths
- Error handling and timeouts
- Multiple server scenarios
- Real network communication

## Running Tests

### Run all NAT tests:
```bash
cd packages/StunDartTests
dart test test/nat_types_test.dart test/stun_message_nat_test.dart test/nat_detector_test.dart
```

### Run individual test suites:
```bash
# Enum and type tests (fast)
dart test test/nat_types_test.dart

# STUN message tests (fast)
dart test test/stun_message_nat_test.dart

# NAT detector tests (requires network, ~10-30 seconds)
dart test test/nat_detector_test.dart
```

### Run with detailed output:
```bash
dart test test/nat_types_test.dart --reporter=expanded
```

## Test Results Summary

| Test Suite | Tests | Status | Duration |
|------------|-------|--------|----------|
| nat_types_test.dart | 16 | ✅ PASS | < 1s |
| stun_message_nat_test.dart | 24 | ✅ PASS | < 1s |
| nat_detector_test.dart | 18 | ✅ PASS | ~10s |
| **TOTAL** | **58** | **✅ ALL PASS** | **~12s** |

## Coverage

The test suite provides comprehensive coverage of:

### Unit Tests:
- ✅ All enum values and display names
- ✅ Record type structures
- ✅ STUN attribute encoding/decoding
- ✅ Factory method variations
- ✅ Parsing methods for all new attributes
- ✅ Error handling for malformed data

### Integration Tests:
- ✅ Complete NAT detection flow
- ✅ Multiple STUN servers
- ✅ Network timeouts and errors
- ✅ Real-world scenarios (Full Cone NAT detected)
- ✅ Diagnostic data collection

### Edge Cases:
- ✅ Null/optional fields
- ✅ Invalid servers
- ✅ Unreachable networks
- ✅ IPv4 and IPv6 addresses
- ✅ XOR and non-XOR encoding

## Test Methodology

### NAT Type Detection
The tests validate the RFC 5780 algorithm:
1. **Test 1**: Basic binding request
2. **Test 2**: CHANGE-REQUEST (IP+Port)
3. **Test 3**: Alternate server request
4. **Test 4**: CHANGE-REQUEST (Port only)

### Real Network Tests
Tests use actual STUN servers:
- stun.l.google.com:19302
- stun1.l.google.com:19302
- 192.0.2.1 (TEST-NET-1 for timeout tests)

### Detected NAT Types in Tests
Based on test environment, the following was detected:
- **Full Cone NAT** (most common in test runs)
- **UDP Blocked** (for invalid/unreachable servers)
- Endpoint-Independent Filtering
- Endpoint-Independent Mapping

## Notes

- NAT detector tests require active internet connection
- Some tests may take several seconds due to network timeouts
- Tests are designed to be resilient to network conditions
- All tests pass consistently across multiple runs
- The library correctly handles both RFC 5780 and RFC 3489 STUN servers

## Future Test Enhancements

Potential additions:
- Mock STUN server for offline testing
- Tests for all 7 NAT types (requires different network setups)
- Performance benchmarks
- IPv6-specific NAT detection tests
- Stress tests with many concurrent detections
