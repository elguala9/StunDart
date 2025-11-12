import 'dart:typed_data';
import 'dart:math';

/// STUN Message Types
class StunMessageType {
  static const int bindingRequest = 0x0001;
  static const int bindingResponse = 0x0101;
  static const int bindingErrorResponse = 0x0111;
}

/// STUN Attribute Types
class StunAttributeType {
  static const int mappedAddress = 0x0001;
  static const int xorMappedAddress = 0x0020;
  static const int software = 0x8022;
  static const int fingerprint = 0x8028;
}

/// STUN Magic Cookie (fixed value in all STUN messages)
const int stunMagicCookie = 0x2112A442;

/// STUN Message class for encoding/decoding STUN packets
class StunMessage {
  final int messageType;
  final Uint8List transactionId;
  final List<StunAttribute> attributes;

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

  /// Get attribute by type
  StunAttribute? getAttribute(int type) {
    for (final attr in attributes) {
      if (attr.type == type) return attr;
    }
    return null;
  }

  /// Extract XOR-MAPPED-ADDRESS as (ip, port)
  ({String ip, int port})? getXorMappedAddress() {
    final attr = getAttribute(StunAttributeType.xorMappedAddress);
    if (attr == null) return null;

    return _parseXorMappedAddress(attr.value, transactionId);
  }

  /// Parse XOR-MAPPED-ADDRESS attribute
  ({String ip, int port})? _parseXorMappedAddress(
    Uint8List value,
    Uint8List transactionId,
  ) {
    if (value.length < 8) return null;

    // Skip first byte (reserved)
    final family = value[1];

    // XOR port with first 2 bytes of magic cookie
    final xPort = (value[2] << 8) | value[3];
    final port = xPort ^ (stunMagicCookie >> 16);

    if (family == 0x01) {
      // IPv4: 8 bytes total (4 bytes address)
      if (value.length < 8) return null;

      final xAddr =
          (value[4] << 24) | (value[5] << 16) | (value[6] << 8) | value[7];
      final addr = xAddr ^ stunMagicCookie;

      final ip =
          '${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}';
      return (ip: ip, port: port);
    } else if (family == 0x02) {
      // IPv6: 20 bytes total (16 bytes address)
      if (value.length < 20) return null;

      // XOR IPv6 address with magic cookie + transaction ID
      final xorKey = BytesBuilder();
      xorKey.add([
        (stunMagicCookie >> 24) & 0xFF,
        (stunMagicCookie >> 16) & 0xFF,
        (stunMagicCookie >> 8) & 0xFF,
        stunMagicCookie & 0xFF,
      ]);
      xorKey.add(transactionId);

      final xorKeyBytes = xorKey.toBytes();
      final ipv6Bytes = Uint8List(16);

      // XOR each byte of the IPv6 address
      for (var i = 0; i < 16; i++) {
        ipv6Bytes[i] = value[4 + i] ^ xorKeyBytes[i];
      }

      // Format as IPv6 string (RFC 5952 format)
      final parts = <String>[];
      for (var i = 0; i < 16; i += 2) {
        final word = (ipv6Bytes[i] << 8) | ipv6Bytes[i + 1];
        parts.add(word.toRadixString(16));
      }

      // Join with colons
      final ip = parts.join(':');
      return (ip: ip, port: port);
    }

    return null;
  }
}

/// STUN Attribute
class StunAttribute {
  final int type;
  final Uint8List value;

  StunAttribute({required this.type, required this.value});

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
