import 'dart:io';
import 'dart:typed_data';
import 'package:callback_handler/callback_handler.dart';

/// IP version type
enum IpVersion {
  v4('IPv4'),
  v6('IPv6');

  const IpVersion(this.value);
  final String value;
}

typedef SingleStunResponse = ({
  String publicIp,
  int publicPort,
  Uint8List transactionId,
  Uint8List raw,
  InternetAddressType type,
  Map<String, dynamic>? attrs
});

/// STUN response containing public IP, port, and transaction information
///
/// Example:
/// ```dart
/// final response = (
///   publicIp: "203.0.113.42",
///   publicPort: 54723,
///   ipVersion: IpVersion.v4,
///   transactionId: Uint8List(12),
///   raw: Uint8List.fromList([...]),
///   attrs: {"key": "value"}
/// );
/// ```
class StunResponse {
  StunResponse(StunResponseInput first, StunResponseInput? second) {
    if (first.ipVersion == null) {
      throw ArgumentError('first.ipVersion must not be null');
    }

    if (second != null) {
      if (second.ipVersion == null) {
        throw ArgumentError('second.ipVersion must not be null');
      }
      if (first.ipVersion == second.ipVersion) {
        throw ArgumentError('first and second cannot have the same IP version');
      }
    }

    _assign(first);
    if (second != null) {
      _assign(second);
    }
  }

  factory StunResponse.merge(StunResponse? v4, StunResponse? v6) {
    final response = StunResponse._internal();
    response._v4 = v4?._v4;
    response._v6 = v6?._v6;
    return response;
  }

  StunResponse._internal();

  SingleStunResponse? _v4;
  SingleStunResponse? _v6;

  String? publicIp(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _v4?.publicIp : _v6?.publicIp;
  int? publicPort(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _v4?.publicPort : _v6?.publicPort;
  Uint8List? transactionId(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _v4?.transactionId : _v6?.transactionId;
  Uint8List? raw(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _v4?.raw : _v6?.raw;
  Map<String, dynamic>? attrs(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? _v4?.attrs : _v6?.attrs;

  void _assign(StunResponseInput input) {
    final single = _toSingleStunResponse(input);
    if (input.ipVersion == IpVersion.v4) {
      _v4 = single;
    } else {
      _v6 = single;
    }
  }

  SingleStunResponse _toSingleStunResponse(StunResponseInput input) => (
    publicIp: input.publicIp,
    publicPort: input.publicPort,
    transactionId: input.transactionId,
    raw: input.raw,
    type: input.ipVersion == IpVersion.v4
        ? InternetAddressType.IPv4
        : InternetAddressType.IPv6,
    attrs: input.attrs,
  );
}

typedef StunResponseInput = ({
  String publicIp,
  IpVersion? ipVersion,
  int publicPort,
  Uint8List transactionId,
  Uint8List raw,
  Map<String, dynamic>? attrs,
});

/// Constructs a [StunResponse] from named IPv4/IPv6 parameters.
StunResponse createStunResponse({
  String? publicIpv4,
  int? publicPortIpv4,
  Uint8List? transactionIdIpv4,
  Uint8List? rawIpv4,
  String? publicIpv6,
  int? publicPortIpv6,
  IpVersion? ipVersionIpv6,
  Uint8List? transactionIdIpv6,
  Uint8List? rawIpv6,
}) {
  StunResponseInput? v4;
  StunResponseInput? v6;

  if (publicIpv4 != null || publicPortIpv4 != null) {
    v4 = (
      publicIp: publicIpv4 ?? '',
      ipVersion: IpVersion.v4,
      publicPort: publicPortIpv4 ?? 0,
      transactionId: transactionIdIpv4 ?? Uint8List(0),
      raw: rawIpv4 ?? Uint8List(0),
      attrs: null,
    );
  }

  if (publicIpv6 != null || publicPortIpv6 != null) {
    v6 = (
      publicIp: publicIpv6 ?? '',
      ipVersion: ipVersionIpv6 ?? IpVersion.v6,
      publicPort: publicPortIpv6 ?? 0,
      transactionId: transactionIdIpv6 ?? Uint8List(0),
      raw: rawIpv6 ?? Uint8List(0),
      attrs: null,
    );
  }

  final first = v4 ?? v6;
  if (first == null) {
    throw ArgumentError('At least one of publicIpv4 or publicIpv6 must be provided.');
  }
  return StunResponse(first, first == v4 ? v6 : null);
}

/// Local network information
class LocalInfo {
  LocalInfo(LocalInfoInput first, LocalInfoInput? second) {
    if (first.ipVersion == null) {
      throw ArgumentError('first.ipVersion must not be null');
    }

    if (second != null) {
      if (second.ipVersion == null) {
        throw ArgumentError('second.ipVersion must not be null');
      }
      if (first.ipVersion == second.ipVersion) {
        throw ArgumentError('first and second cannot have the same IP version');
      }
    }

    _assign(first);
    if (second != null) {
      _assign(second);
    }
  }

  factory LocalInfo.merge(LocalInfo? v4, LocalInfo? v6) {
    final info = LocalInfo._internal();
    if (v4 != null) {
      info.localIpv4 = v4.localIpv4;
      info.localPortIpv4 = v4.localPortIpv4;
    }
    if (v6 != null) {
      info.localIpv6 = v6.localIpv6;
      info.localPortIpv6 = v6.localPortIpv6;
    }
    return info;
  }

  LocalInfo._internal();

  String? localIpv4;
  int? localPortIpv4;
  String? localIpv6;
  int? localPortIpv6;

  void _assign(LocalInfoInput input) {
    if (input.ipVersion == IpVersion.v4) {
      localIpv4 = input.localIp;
      localPortIpv4 = input.localPort;
    } else {
      localIpv6 = input.localIp;
      localPortIpv6 = input.localPort;
    }
  }
}

typedef LocalInfoInput = ({
  String localIp,
  IpVersion? ipVersion,
  int localPort,
});

/// Input parameters for StunHandler constructor
typedef StunHandlerInput = ({
  String? address, // stun server address
  int? port, // stun server port
  RawDatagramSocket?
  socket, // optional socket; if null, will be created internally
});

/// Socket refresh callback handler using callback_handler library
/// Fired when StunHandler recreates its socket after a network error.
/// [newResponse] is the first successful result on the new socket.
/// [oldResponse] is the cached result before the error (null if cache was empty).
typedef OnSocketRefresh =
    void Function(StunResponse newResponse, StunResponse? oldResponse);

typedef IpCallbackHandler =
    CallbackHandler<(StunResponse, StunResponse?), void>;

/// NAT type classifications per RFC 5780 and RFC 3489
enum NATType {
  openInternet('Open Internet'),
  fullCone('Full Cone NAT'),
  restrictedCone('Restricted Cone NAT'),
  portRestrictedCone('Port Restricted Cone NAT'),
  symmetric('Symmetric NAT'),
  symmetricFirewall('Symmetric UDP Firewall'),
  udpBlocked('UDP Blocked');

  const NATType(this.displayName);
  final String displayName;
}

/// NAT filtering behavior (endpoint-independent vs endpoint-dependent)
enum NATFilteringBehavior {
  endpointIndependent('Endpoint-Independent Filtering'),
  addressDependent('Address-Dependent Filtering'),
  addressAndPortDependent('Address and Port-Dependent Filtering'),
  unknown('Unknown');

  const NATFilteringBehavior(this.displayName);
  final String displayName;
}

/// NAT mapping behavior
enum NATMappingBehavior {
  endpointIndependent('Endpoint-Independent Mapping'),
  addressDependent('Address-Dependent Mapping'),
  addressAndPortDependent('Address and Port-Dependent Mapping'),
  unknown('Unknown');

  const NATMappingBehavior(this.displayName);
  final String displayName;
}

/// Result of NAT type detection
///
/// Example:
/// ```dart
/// final result = await detector.detectNATType();
/// print('NAT Type: ${result.natType.displayName}');
/// print('Public IP: ${result.publicIp}:${result.publicPort}');
/// ```
typedef NATDetectionResult = ({
  NATType natType,
  NATFilteringBehavior filteringBehavior,
  NATMappingBehavior mappingBehavior,
  String? publicIp,
  int? publicPort,
  String? alternateIp,
  int? alternatePort,
  bool rfc5780Supported,
  Duration detectionTime,
  Map<String, dynamic> diagnostics,
});
