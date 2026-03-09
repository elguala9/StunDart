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
typedef StunResponse = ({
  String publicIp, // Es: "203.0.113.42" o "2001:db8::1"
  int publicPort, // Es: 54723
  IpVersion ipVersion, // IpVersion.v4 o IpVersion.v6
  Uint8List transactionId, // Transaction ID della richiesta STUN (12 byte)
  Uint8List raw, // Il pacchetto STUN ricevuto (binario)
  Map<String, dynamic>? attrs, // Eventuali altri attributi STUN
});

/// Local network information
///
/// Example:
/// ```dart
/// final info = (localIp: "192.168.1.2", localPort: 12345);
/// ```
typedef LocalInfo = ({
  String localIp, // Es: "192.168.1.2"
  int localPort, // Es: 12345
});

/// Input parameters for StunHandler constructor
typedef StunHandlerInput = ({
  String? address, // stun server address
  int? port, // stun server port
  RawDatagramSocket? socket, // optional socket; if null, will be created internally
});

/// Socket refresh callback handler using callback_handler library
/// Fired when StunHandler recreates its socket after a network error.
/// [newResponse] is the first successful result on the new socket.
/// [oldResponse] is the cached result before the error (null if cache was empty).
typedef OnSocketRefresh = void Function(
  StunResponse newResponse,
  StunResponse? oldResponse,
);

/// Socket refresh callback handler for StunHandlerSingleton
/// Fired when one of its handlers recreates its socket.
/// [ipv6] identifies which handler (false = IPv4, true = IPv6).
typedef OnSingletonSocketRefresh = void Function(
  StunResponse newResponse,
  StunResponse? oldResponse, {
  required bool ipv6,
});

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
