import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../implementations/config/stun_constants.dart';
import '../implementations/request/stun_message.dart';

/// Internal-only attribute-parsing behavior of `StunMessage`. The mixing
/// class provides the raw attributes and transaction ID. Not part of the
/// package's public API — do not export it from `stun.dart`.
@internal
mixin StunMessageMixin {
  /// Attributes provided by the mixing class.
  List<StunAttribute> get attributes;

  /// Transaction ID provided by the mixing class.
  Uint8List get transactionId;

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

  /// Extract OTHER-ADDRESS attribute (RFC 5780)
  ///
  /// This attribute contains the alternate server IP and port that can be used
  /// for NAT type detection. Returns null if the attribute is not present.
  ({String ip, int port})? getOtherAddress() {
    final attr = getAttribute(StunAttributeType.otherAddress);
    if (attr == null) return null;
    return _parseXorMappedAddress(attr.value, transactionId);
  }

  /// Extract CHANGED-ADDRESS attribute (RFC 3489)
  ///
  /// This is a legacy attribute used by older STUN servers. It provides
  /// the alternate server address without XOR encoding.
  /// Returns null if the attribute is not present.
  ({String ip, int port})? getChangedAddress() {
    final attr = getAttribute(StunAttributeType.changedAddress);
    if (attr == null) return null;
    return _parseMappedAddress(attr.value);
  }

  /// Extract RESPONSE-ORIGIN attribute (RFC 5780)
  ///
  /// This attribute indicates the IP address and port from which the
  /// response was sent. Useful for verifying the server's behavior.
  /// Returns null if the attribute is not present.
  ({String ip, int port})? getResponseOrigin() {
    final attr = getAttribute(StunAttributeType.responseOrigin);
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

  /// Parse plain MAPPED-ADDRESS attribute (non-XOR, RFC 3489)
  ///
  /// This is used for legacy STUN servers that don't support XOR encoding.
  ({String ip, int port})? _parseMappedAddress(Uint8List value) {
    if (value.length < 8) return null;

    final family = value[1];
    final port = (value[2] << 8) | value[3];

    if (family == 0x01) {
      // IPv4
      if (value.length < 8) return null;
      final ip = '${value[4]}.${value[5]}.${value[6]}.${value[7]}';
      return (ip: ip, port: port);
    } else if (family == 0x02) {
      // IPv6
      if (value.length < 20) return null;
      final parts = <String>[];
      for (var i = 0; i < 16; i += 2) {
        final word = (value[4 + i] << 8) | value[4 + i + 1];
        parts.add(word.toRadixString(16));
      }
      return (ip: parts.join(':'), port: port);
    }

    return null;
  }
}
