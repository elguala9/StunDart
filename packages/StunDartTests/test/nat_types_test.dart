import 'package:stun/stun.dart';
import 'package:test/test.dart';

/// Test suite for NAT type enums and typedefs
void main() {
  group('NATType enum', () {
    test('should have correct number of types', () {
      expect(NATType.values.length, equals(7));
    });

    test('should have correct display names', () {
      expect(NATType.openInternet.displayName, equals('Open Internet'));
      expect(NATType.fullCone.displayName, equals('Full Cone NAT'));
      expect(NATType.restrictedCone.displayName, equals('Restricted Cone NAT'));
      expect(
        NATType.portRestrictedCone.displayName,
        equals('Port Restricted Cone NAT'),
      );
      expect(NATType.symmetric.displayName, equals('Symmetric NAT'));
      expect(
        NATType.symmetricFirewall.displayName,
        equals('Symmetric UDP Firewall'),
      );
      expect(NATType.udpBlocked.displayName, equals('UDP Blocked'));
    });

    test('should support enum equality', () {
      expect(NATType.fullCone, equals(NATType.fullCone));
      expect(NATType.fullCone, isNot(equals(NATType.symmetric)));
    });

    test('should support switch statements', () {
      String getDescription(NATType type) {
        switch (type) {
          case NATType.openInternet:
            return 'no nat';
          case NATType.fullCone:
            return 'full cone';
          case NATType.restrictedCone:
            return 'restricted';
          case NATType.portRestrictedCone:
            return 'port restricted';
          case NATType.symmetric:
            return 'symmetric';
          case NATType.symmetricFirewall:
            return 'firewall';
          case NATType.udpBlocked:
            return 'blocked';
        }
      }

      expect(getDescription(NATType.fullCone), equals('full cone'));
      expect(getDescription(NATType.symmetric), equals('symmetric'));
    });
  });

  group('NATFilteringBehavior enum', () {
    test('should have correct number of behaviors', () {
      expect(NATFilteringBehavior.values.length, equals(4));
    });

    test('should have correct display names', () {
      expect(
        NATFilteringBehavior.endpointIndependent.displayName,
        equals('Endpoint-Independent Filtering'),
      );
      expect(
        NATFilteringBehavior.addressDependent.displayName,
        equals('Address-Dependent Filtering'),
      );
      expect(
        NATFilteringBehavior.addressAndPortDependent.displayName,
        equals('Address and Port-Dependent Filtering'),
      );
      expect(
        NATFilteringBehavior.unknown.displayName,
        equals('Unknown'),
      );
    });

    test('should support enum equality', () {
      expect(
        NATFilteringBehavior.endpointIndependent,
        equals(NATFilteringBehavior.endpointIndependent),
      );
      expect(
        NATFilteringBehavior.endpointIndependent,
        isNot(equals(NATFilteringBehavior.addressDependent)),
      );
    });
  });

  group('NATMappingBehavior enum', () {
    test('should have correct number of behaviors', () {
      expect(NATMappingBehavior.values.length, equals(4));
    });

    test('should have correct display names', () {
      expect(
        NATMappingBehavior.endpointIndependent.displayName,
        equals('Endpoint-Independent Mapping'),
      );
      expect(
        NATMappingBehavior.addressDependent.displayName,
        equals('Address-Dependent Mapping'),
      );
      expect(
        NATMappingBehavior.addressAndPortDependent.displayName,
        equals('Address and Port-Dependent Mapping'),
      );
      expect(
        NATMappingBehavior.unknown.displayName,
        equals('Unknown'),
      );
    });

    test('should support enum equality', () {
      expect(
        NATMappingBehavior.endpointIndependent,
        equals(NATMappingBehavior.endpointIndependent),
      );
      expect(
        NATMappingBehavior.endpointIndependent,
        isNot(equals(NATMappingBehavior.addressDependent)),
      );
    });
  });

  group('NATDetectionResult typedef', () {
    test('should create valid result record', () {
      final result = (
        natType: NATType.fullCone,
        filteringBehavior: NATFilteringBehavior.endpointIndependent,
        mappingBehavior: NATMappingBehavior.endpointIndependent,
        publicIp: '203.0.113.42',
        publicPort: 54321,
        alternateIp: '203.0.113.43',
        alternatePort: 3478,
        rfc5780Supported: true,
        detectionTime: const Duration(milliseconds: 1500),
        diagnostics: {'test1': 'success'},
      );

      expect(result.natType, equals(NATType.fullCone));
      expect(
        result.filteringBehavior,
        equals(NATFilteringBehavior.endpointIndependent),
      );
      expect(
        result.mappingBehavior,
        equals(NATMappingBehavior.endpointIndependent),
      );
      expect(result.publicIp, equals('203.0.113.42'));
      expect(result.publicPort, equals(54321));
      expect(result.alternateIp, equals('203.0.113.43'));
      expect(result.alternatePort, equals(3478));
      expect(result.rfc5780Supported, isTrue);
      expect(result.detectionTime.inMilliseconds, equals(1500));
      expect(result.diagnostics, containsPair('test1', 'success'));
    });

    test('should support null optional fields', () {
      final result = (
        natType: NATType.udpBlocked,
        filteringBehavior: NATFilteringBehavior.unknown,
        mappingBehavior: NATMappingBehavior.unknown,
        publicIp: null,
        publicPort: null,
        alternateIp: null,
        alternatePort: null,
        rfc5780Supported: false,
        detectionTime: const Duration(milliseconds: 5000),
        diagnostics: <String, dynamic>{},
      );

      expect(result.natType, equals(NATType.udpBlocked));
      expect(result.publicIp, isNull);
      expect(result.publicPort, isNull);
      expect(result.alternateIp, isNull);
      expect(result.alternatePort, isNull);
      expect(result.rfc5780Supported, isFalse);
    });

    test('should support symmetric NAT result', () {
      final result = (
        natType: NATType.symmetric,
        filteringBehavior: NATFilteringBehavior.addressAndPortDependent,
        mappingBehavior: NATMappingBehavior.addressAndPortDependent,
        publicIp: '198.51.100.1',
        publicPort: 12345,
        alternateIp: '198.51.100.2',
        alternatePort: 19302,
        rfc5780Supported: true,
        detectionTime: const Duration(milliseconds: 3500),
        diagnostics: {
          'test1': {'success': true, 'port': 12345},
          'test2': {'success': false},
          'test3': {'success': true, 'port': 54321}, // Different port!
        },
      );

      expect(result.natType, equals(NATType.symmetric));
      expect(
        result.filteringBehavior,
        equals(NATFilteringBehavior.addressAndPortDependent),
      );
      expect(
        result.mappingBehavior,
        equals(NATMappingBehavior.addressAndPortDependent),
      );
      expect(result.diagnostics.length, equals(3));
    });

    test('should support diagnostics with complex data', () {
      final result = (
        natType: NATType.restrictedCone,
        filteringBehavior: NATFilteringBehavior.addressDependent,
        mappingBehavior: NATMappingBehavior.endpointIndependent,
        publicIp: '192.0.2.1',
        publicPort: 9999,
        alternateIp: null,
        alternatePort: null,
        rfc5780Supported: false,
        detectionTime: const Duration(seconds: 2),
        diagnostics: {
          'test1': {
            'success': true,
            'publicIp': '192.0.2.1',
            'publicPort': 9999,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'test2': {'success': false, 'error': 'timeout'},
          'test3': {'skipped': true, 'reason': 'No alternate server'},
          'test4': {'success': true},
        },
      );

      expect(result.diagnostics.keys, contains('test1'));
      expect(result.diagnostics.keys, contains('test2'));
      expect(result.diagnostics.keys, contains('test3'));
      expect(result.diagnostics.keys, contains('test4'));
      expect(
        (result.diagnostics['test1'] as Map)['success'],
        isTrue,
      );
      expect(
        (result.diagnostics['test2'] as Map)['error'],
        equals('timeout'),
      );
    });
  });

  group('Enum usage in real scenarios', () {
    test('should handle all NAT types in a comprehensive switch', () {
      int countHandledCases = 0;

      for (final natType in NATType.values) {
        switch (natType) {
          case NATType.openInternet:
          case NATType.fullCone:
          case NATType.restrictedCone:
          case NATType.portRestrictedCone:
          case NATType.symmetric:
          case NATType.symmetricFirewall:
          case NATType.udpBlocked:
            countHandledCases++;
        }
      }

      expect(countHandledCases, equals(NATType.values.length));
    });

    test('should provide meaningful toString representations', () {
      expect(
        NATType.fullCone.displayName,
        contains('Cone'),
      );
      expect(
        NATType.symmetric.displayName,
        contains('Symmetric'),
      );
      expect(
        NATFilteringBehavior.endpointIndependent.displayName,
        contains('Endpoint-Independent'),
      );
    });
  });
}
