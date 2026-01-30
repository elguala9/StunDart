import 'dart:typed_data';
import 'package:stun/src/implementations/stun_message.dart';
import 'package:test/test.dart';

/// Test suite for new STUN message NAT detection features
void main() {
  group('StunAttributeType - New NAT attributes', () {
    test('should have CHANGE-REQUEST attribute type', () {
      expect(StunAttributeType.changeRequest, equals(0x0003));
    });

    test('should have CHANGED-ADDRESS attribute type', () {
      expect(StunAttributeType.changedAddress, equals(0x0005));
    });

    test('should have RESPONSE-ORIGIN attribute type', () {
      expect(StunAttributeType.responseOrigin, equals(0x802b));
    });

    test('should have OTHER-ADDRESS attribute type', () {
      expect(StunAttributeType.otherAddress, equals(0x802c));
    });

    test('all attribute types should be unique', () {
      final types = [
        StunAttributeType.mappedAddress,
        StunAttributeType.changeRequest,
        StunAttributeType.changedAddress,
        StunAttributeType.xorMappedAddress,
        StunAttributeType.software,
        StunAttributeType.fingerprint,
        StunAttributeType.responseOrigin,
        StunAttributeType.otherAddress,
      ];

      final uniqueTypes = types.toSet();
      expect(uniqueTypes.length, equals(types.length));
    });
  });

  group('createBindingRequestWithChangeRequest factory', () {
    test('should create request with no flags', () {
      final request = StunMessage.createBindingRequestWithChangeRequest();

      expect(request.messageType, equals(StunMessageType.bindingRequest));
      expect(request.transactionId.length, equals(12));
      expect(request.attributes.length, equals(1));

      final attr = request.attributes[0];
      expect(attr.type, equals(StunAttributeType.changeRequest));
      expect(attr.value.length, equals(4));
      expect(attr.value[3], equals(0)); // No flags set
    });

    test('should create request with changeIp flag only', () {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: false,
      );

      final attr = request.attributes[0];
      expect(attr.value[3], equals(0x04)); // Bit 2 set
    });

    test('should create request with changePort flag only', () {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: false,
        changePort: true,
      );

      final attr = request.attributes[0];
      expect(attr.value[3], equals(0x02)); // Bit 1 set
    });

    test('should create request with both flags', () {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: true,
      );

      final attr = request.attributes[0];
      expect(attr.value[3], equals(0x06)); // Both bits set (0x04 | 0x02)
    });

    test('should have correct STUN message structure', () {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: true,
      );

      final bytes = request.toBytes();

      // Check header
      expect(bytes.length, greaterThanOrEqualTo(20)); // Minimum STUN header
      expect(bytes[0], equals(0x00)); // Message type high byte
      expect(bytes[1], equals(0x01)); // Binding Request

      // Check magic cookie
      expect(bytes[4], equals(0x21));
      expect(bytes[5], equals(0x12));
      expect(bytes[6], equals(0xA4));
      expect(bytes[7], equals(0x42));
    });

    test('should generate unique transaction IDs', () {
      final request1 = StunMessage.createBindingRequestWithChangeRequest();
      final request2 = StunMessage.createBindingRequestWithChangeRequest();

      // Very unlikely to be the same (1 in 2^96)
      bool areEqual = true;
      for (var i = 0; i < 12; i++) {
        if (request1.transactionId[i] != request2.transactionId[i]) {
          areEqual = false;
          break;
        }
      }
      expect(areEqual, isFalse);
    });

    test('should encode and decode correctly', () {
      final originalRequest = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: false,
      );

      final bytes = originalRequest.toBytes();
      final decodedRequest = StunMessage.fromBytes(bytes);

      expect(decodedRequest.messageType, equals(originalRequest.messageType));
      expect(
        decodedRequest.transactionId,
        equals(originalRequest.transactionId),
      );
      expect(decodedRequest.attributes.length, equals(1));

      final attr = decodedRequest.getAttribute(StunAttributeType.changeRequest);
      expect(attr, isNotNull);
      expect(attr!.value[3], equals(0x04));
    });
  });

  group('getOtherAddress method', () {
    test('should return null when attribute is missing', () {
      final message = StunMessage.createBindingRequest();
      expect(message.getOtherAddress(), isNull);
    });

    test('should parse IPv4 OTHER-ADDRESS attribute', () {
      // Create a mock STUN response with OTHER-ADDRESS
      final transactionId = Uint8List(12);
      for (var i = 0; i < 12; i++) {
        transactionId[i] = i;
      }

      // XOR-MAPPED-ADDRESS format for 192.0.2.1:3478
      // Family: 0x01 (IPv4)
      // X-Port: 3478 XOR 0x2112 = 3478 ^ 8466 = 9340 (0x247C)
      // X-Address: 192.0.2.1 XOR 0x2112A442
      final ip = 0xC0000201; // 192.0.2.1
      final xorIp = ip ^ 0x2112A442;
      final port = 3478 ^ 0x2112;

      final attrValue = Uint8List.fromList([
        0x00, // Reserved
        0x01, // Family IPv4
        (port >> 8) & 0xFF,
        port & 0xFF,
        (xorIp >> 24) & 0xFF,
        (xorIp >> 16) & 0xFF,
        (xorIp >> 8) & 0xFF,
        xorIp & 0xFF,
      ]);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: transactionId,
        attributes: [
          StunAttribute(
            type: StunAttributeType.otherAddress,
            value: attrValue,
          ),
        ],
      );

      final result = message.getOtherAddress();
      expect(result, isNotNull);
      expect(result!.ip, equals('192.0.2.1'));
      expect(result.port, equals(3478));
    });
  });

  group('getChangedAddress method', () {
    test('should return null when attribute is missing', () {
      final message = StunMessage.createBindingRequest();
      expect(message.getChangedAddress(), isNull);
    });

    test('should parse IPv4 CHANGED-ADDRESS attribute (non-XOR)', () {
      // CHANGED-ADDRESS uses plain encoding (RFC 3489)
      final attrValue = Uint8List.fromList([
        0x00, // Reserved
        0x01, // Family IPv4
        0x0D, // Port high byte (3478 = 0x0D96)
        0x96, // Port low byte
        192, // IP octet 1
        0, // IP octet 2
        2, // IP octet 3
        1, // IP octet 4
      ]);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: Uint8List(12),
        attributes: [
          StunAttribute(
            type: StunAttributeType.changedAddress,
            value: attrValue,
          ),
        ],
      );

      final result = message.getChangedAddress();
      expect(result, isNotNull);
      expect(result!.ip, equals('192.0.2.1'));
      expect(result.port, equals(3478));
    });

    test('should parse IPv6 CHANGED-ADDRESS attribute', () {
      // IPv6 address: 2001:db8::1
      final attrValue = Uint8List.fromList([
        0x00, // Reserved
        0x02, // Family IPv6
        0x0D, // Port high byte
        0x96, // Port low byte
        0x20, 0x01, // 2001
        0x0d, 0xb8, // db8
        0x00, 0x00, // 0
        0x00, 0x00, // 0
        0x00, 0x00, // 0
        0x00, 0x00, // 0
        0x00, 0x00, // 0
        0x00, 0x01, // 1
      ]);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: Uint8List(12),
        attributes: [
          StunAttribute(
            type: StunAttributeType.changedAddress,
            value: attrValue,
          ),
        ],
      );

      final result = message.getChangedAddress();
      expect(result, isNotNull);
      expect(result!.ip, contains(':'));
      expect(result.port, equals(3478));
    });

    test('should handle malformed attribute gracefully', () {
      // Too short attribute
      final attrValue = Uint8List.fromList([0x00, 0x01, 0x00]);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: Uint8List(12),
        attributes: [
          StunAttribute(
            type: StunAttributeType.changedAddress,
            value: attrValue,
          ),
        ],
      );

      final result = message.getChangedAddress();
      expect(result, isNull);
    });
  });

  group('getResponseOrigin method', () {
    test('should return null when attribute is missing', () {
      final message = StunMessage.createBindingRequest();
      expect(message.getResponseOrigin(), isNull);
    });

    test('should parse RESPONSE-ORIGIN attribute', () {
      final transactionId = Uint8List(12);
      for (var i = 0; i < 12; i++) {
        transactionId[i] = i;
      }

      // XOR-encoded address
      final ip = 0xC0000201; // 192.0.2.1
      final xorIp = ip ^ 0x2112A442;
      final port = 19302 ^ 0x2112;

      final attrValue = Uint8List.fromList([
        0x00, // Reserved
        0x01, // Family IPv4
        (port >> 8) & 0xFF,
        port & 0xFF,
        (xorIp >> 24) & 0xFF,
        (xorIp >> 16) & 0xFF,
        (xorIp >> 8) & 0xFF,
        xorIp & 0xFF,
      ]);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: transactionId,
        attributes: [
          StunAttribute(
            type: StunAttributeType.responseOrigin,
            value: attrValue,
          ),
        ],
      );

      final result = message.getResponseOrigin();
      expect(result, isNotNull);
      expect(result!.ip, equals('192.0.2.1'));
      expect(result.port, equals(19302));
    });
  });

  group('Integration - Multiple NAT attributes', () {
    test('should handle message with all NAT attributes', () {
      final transactionId = Uint8List(12);

      // Create XOR-encoded values
      final ip1 = 0xC0000201; // 192.0.2.1
      final xorIp1 = ip1 ^ 0x2112A442;
      final port1 = 3478 ^ 0x2112;

      final ip2 = 0xC0000202; // 192.0.2.2
      final xorIp2 = ip2 ^ 0x2112A442;
      final port2 = 19302 ^ 0x2112;

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: transactionId,
        attributes: [
          // XOR-MAPPED-ADDRESS
          StunAttribute(
            type: StunAttributeType.xorMappedAddress,
            value: Uint8List.fromList([
              0x00,
              0x01,
              (port1 >> 8) & 0xFF,
              port1 & 0xFF,
              (xorIp1 >> 24) & 0xFF,
              (xorIp1 >> 16) & 0xFF,
              (xorIp1 >> 8) & 0xFF,
              xorIp1 & 0xFF,
            ]),
          ),
          // OTHER-ADDRESS
          StunAttribute(
            type: StunAttributeType.otherAddress,
            value: Uint8List.fromList([
              0x00,
              0x01,
              (port2 >> 8) & 0xFF,
              port2 & 0xFF,
              (xorIp2 >> 24) & 0xFF,
              (xorIp2 >> 16) & 0xFF,
              (xorIp2 >> 8) & 0xFF,
              xorIp2 & 0xFF,
            ]),
          ),
          // RESPONSE-ORIGIN
          StunAttribute(
            type: StunAttributeType.responseOrigin,
            value: Uint8List.fromList([
              0x00,
              0x01,
              (port1 >> 8) & 0xFF,
              port1 & 0xFF,
              (xorIp1 >> 24) & 0xFF,
              (xorIp1 >> 16) & 0xFF,
              (xorIp1 >> 8) & 0xFF,
              xorIp1 & 0xFF,
            ]),
          ),
        ],
      );

      final xorMapped = message.getXorMappedAddress();
      final other = message.getOtherAddress();
      final responseOrigin = message.getResponseOrigin();

      expect(xorMapped, isNotNull);
      expect(xorMapped!.ip, equals('192.0.2.1'));
      expect(xorMapped.port, equals(3478));

      expect(other, isNotNull);
      expect(other!.ip, equals('192.0.2.2'));
      expect(other.port, equals(19302));

      expect(responseOrigin, isNotNull);
      expect(responseOrigin!.ip, equals('192.0.2.1'));
      expect(responseOrigin.port, equals(3478));
    });

    test('should handle mixed XOR and non-XOR attributes', () {
      final transactionId = Uint8List(12);

      final message = StunMessage(
        messageType: StunMessageType.bindingResponse,
        transactionId: transactionId,
        attributes: [
          // CHANGED-ADDRESS (non-XOR)
          StunAttribute(
            type: StunAttributeType.changedAddress,
            value: Uint8List.fromList([
              0x00,
              0x01,
              0x0D,
              0x96, // Port 3478
              192,
              0,
              2,
              1, // 192.0.2.1
            ]),
          ),
          // OTHER-ADDRESS (XOR)
          StunAttribute(
            type: StunAttributeType.otherAddress,
            value: Uint8List.fromList([
              0x00,
              0x01,
              ((3478 ^ 0x2112) >> 8) & 0xFF,
              (3478 ^ 0x2112) & 0xFF,
              ((0xC0000202 ^ 0x2112A442) >> 24) & 0xFF,
              ((0xC0000202 ^ 0x2112A442) >> 16) & 0xFF,
              ((0xC0000202 ^ 0x2112A442) >> 8) & 0xFF,
              (0xC0000202 ^ 0x2112A442) & 0xFF,
            ]),
          ),
        ],
      );

      final changed = message.getChangedAddress();
      final other = message.getOtherAddress();

      expect(changed, isNotNull);
      expect(changed!.ip, equals('192.0.2.1'));

      expect(other, isNotNull);
      expect(other!.ip, equals('192.0.2.2'));

      // Different IPs as expected
      expect(changed.ip, isNot(equals(other.ip)));
    });
  });

  group('Attribute encoding/decoding roundtrip', () {
    test('should survive encode-decode cycle for CHANGE-REQUEST', () {
      final original = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: true,
      );

      final encoded = original.toBytes();
      final decoded = StunMessage.fromBytes(encoded);

      final attr = decoded.getAttribute(StunAttributeType.changeRequest);
      expect(attr, isNotNull);
      expect(attr!.value.length, equals(4));
      expect(attr.value[3], equals(0x06)); // Both flags
    });

    test('should maintain transaction ID through encode-decode', () {
      final original = StunMessage.createBindingRequestWithChangeRequest();
      final encoded = original.toBytes();
      final decoded = StunMessage.fromBytes(encoded);

      expect(decoded.transactionId, equals(original.transactionId));
    });
  });
}
