import 'dart:typed_data';
import 'dart:math';
import '../../config/stun_constants.dart';
import '../../mixins/single/stun_message_mixin.dart';

// Re-export types from stun_constants for convenience
export '../../config/stun_constants.dart' show StunMessageType, StunAttributeType;

/// STUN Message class for encoding/decoding STUN packets
class StunMessage with StunMessageMixin {
  StunMessage({
    required this.messageType,
    required this.transactionId,
    this.attributes = const [],
  });

  /// Create a STUN Binding Request
  factory StunMessage.createBindingRequest() {
    final transactionId = _generateTransactionId();
    return StunMessage(
      messageType: StunMessageType.bindingRequest,
      transactionId: transactionId,
    );
  }

  /// Create a STUN Binding Request with CHANGE-REQUEST attribute
  ///
  /// The CHANGE-REQUEST attribute is used to request that the server
  /// send the response from a different IP address and/or port.
  ///
  /// Example:
  /// ```dart
  /// // Request response from different IP and port
  /// final request = StunMessage.createBindingRequestWithChangeRequest(
  ///   changeIp: true,
  ///   changePort: true,
  /// );
  /// ```
  factory StunMessage.createBindingRequestWithChangeRequest({
    bool changeIp = false,
    bool changePort = false,
  }) {
    final transactionId = _generateTransactionId();

    // CHANGE-REQUEST: 4 bytes with flags in byte 3
    // Bit 2 (0x04) = change IP, Bit 1 (0x02) = change port
    final flags = (changeIp ? 0x04 : 0) | (changePort ? 0x02 : 0);
    final changeRequestValue = Uint8List(4);
    changeRequestValue[3] = flags;

    return StunMessage(
      messageType: StunMessageType.bindingRequest,
      transactionId: transactionId,
      attributes: [
        StunAttribute(
          type: StunAttributeType.changeRequest,
          value: changeRequestValue,
        ),
      ],
    );
  }

  /// Decode STUN message from bytes
  factory StunMessage.fromBytes(Uint8List data) {
    if (data.length < 20) {
      throw const FormatException('STUN message too short');
    }

    // Parse message type
    final messageType = (data[0] << 8) | data[1];

    // Parse message length
    final messageLength = (data[2] << 8) | data[3];

    // Verify magic cookie
    final magicCookie =
        (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
    if (magicCookie != stunMagicCookie) {
      throw const FormatException('Invalid STUN magic cookie');
    }

    // Parse transaction ID
    final transactionId = Uint8List.fromList(data.sublist(8, 20));

    // Parse attributes
    final attributes = <StunAttribute>[];
    var offset = 20;

    while (offset < data.length && offset < 20 + messageLength) {
      if (offset + 4 > data.length) break;

      final attrType = (data[offset] << 8) | data[offset + 1];
      final attrLength = (data[offset + 2] << 8) | data[offset + 3];
      offset += 4;

      if (offset + attrLength > data.length) break;

      final attrValue = Uint8List.fromList(
        data.sublist(offset, offset + attrLength),
      );
      attributes.add(StunAttribute(type: attrType, value: attrValue));

      // Attributes are padded to 4-byte boundary
      offset += attrLength;
      final padding = (4 - (attrLength % 4)) % 4;
      offset += padding;
    }

    return StunMessage(
      messageType: messageType,
      transactionId: transactionId,
      attributes: attributes,
    );
  }

  final int messageType;

  @override
  final Uint8List transactionId;

  @override
  final List<StunAttribute> attributes;

  /// Generate random 96-bit (12 bytes) transaction ID
  static Uint8List _generateTransactionId() {
    final random = Random.secure();
    final bytes = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Encode STUN message to bytes
  Uint8List toBytes() {
    final buffer = BytesBuilder();

    // Message Type (2 bytes)
    buffer.add([messageType >> 8, messageType & 0xFF]);

    // Message Length (2 bytes) - will be updated after adding attributes
    buffer.add([0, 0]);

    // Magic Cookie (4 bytes)
    buffer.add([
      (stunMagicCookie >> 24) & 0xFF,
      (stunMagicCookie >> 16) & 0xFF,
      (stunMagicCookie >> 8) & 0xFF,
      stunMagicCookie & 0xFF,
    ]);

    // Transaction ID (12 bytes)
    buffer.add(transactionId);

    // Attributes
    final attributesBytes = BytesBuilder();
    for (final attr in attributes) {
      attributesBytes.add(attr.toBytes());
    }

    final attrData = attributesBytes.toBytes();
    buffer.add(attrData);

    // Update message length
    final result = buffer.toBytes();
    final length = attrData.length;
    result[2] = (length >> 8) & 0xFF;
    result[3] = length & 0xFF;

    return result;
  }
}

/// STUN Attribute
class StunAttribute {
  StunAttribute({required this.type, required this.value});

  final int type;
  final Uint8List value;

  Uint8List toBytes() {
    final buffer = BytesBuilder();

    // Type (2 bytes)
    buffer.add([type >> 8, type & 0xFF]);

    // Length (2 bytes)
    buffer.add([value.length >> 8, value.length & 0xFF]);

    // Value
    buffer.add(value);

    // Padding to 4-byte boundary
    final padding = (4 - (value.length % 4)) % 4;
    for (var i = 0; i < padding; i++) {
      buffer.addByte(0);
    }

    return buffer.toBytes();
  }
}
