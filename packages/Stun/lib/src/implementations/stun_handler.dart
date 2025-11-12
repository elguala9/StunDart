import 'dart:io';
import 'dart:async';

import '/src/implementations/stun_config.dart';
import '/src/implementations/stun_message.dart';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';

/// STUN handler implementation
class StunHandler implements IStunHandler {
  /// STUN server address
  String _stunAddress = defaultStunConfig.address;

  /// STUN server port
  int _stunPort = defaultStunConfig.port;

  /// UDP socket for communication
  final RawDatagramSocket _socket;

  /// Creates a STUN handler with the provided configuration
  StunHandler(StunHandlerInput input)
    : _socket = input.socket,
      _stunAddress = input.address ?? defaultStunConfig.address,
      _stunPort = input.port ?? defaultStunConfig.port;

  /// Performs a local network request to get local IP and port
  @override
  Future<LocalInfo> performLocalRequest() async {
    final localIp = await _getLocalIp();
    return (localIp: localIp, localPort: _socket.port);
  }

  /// Returns the underlying UDP socket
  @override
  RawDatagramSocket getSocket() => _socket;

  /// Closes the UDP socket
  @override
  void close() {
    _socket.close();
  }

  /// Updates the STUN server address and port
  @override
  void setStunServer(String address, int port) {
    _stunAddress = address.trim().isNotEmpty
        ? address
        : defaultStunConfig.address;
    _stunPort = (port > 0 && port < 65536) ? port : defaultStunConfig.port;
  }

  /// Performs a STUN binding request to discover the public IP and port
  @override
  Future<StunResponse> performStunRequest() async {
    // Create STUN binding request message
    final request = StunMessage.createBindingRequest();
    final requestBytes = request.toBytes();

    // Determine IP version from socket
    final isIPv6Socket = _socket.address.type == InternetAddressType.IPv6;

    // Log local socket info
    print('[StunHandler] Local socket: ${_socket.address}:${_socket.port}');

    // Send request to STUN server
    final stunServerAddr = await InternetAddress.lookup(
      _stunAddress,
      type: isIPv6Socket ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
    );
    if (stunServerAddr.isEmpty) {
      throw StateError('Could not resolve STUN server address: $_stunAddress');
    }

    final targetAddr = stunServerAddr.first;
    print('[StunHandler] Sending STUN request to $targetAddr:$_stunPort');

    _socket.send(requestBytes, targetAddr, _stunPort);

    final completer = Completer<StunResponse>();

    // Listen for response from STUN server
    StreamSubscription<RawSocketEvent>? subscription;
    subscription = _socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket.receive();
        if (datagram == null) return;

        // Parse STUN response
        final stunResponse = StunMessage.fromBytes(datagram.data);
        final xorMappedAddr = stunResponse.getXorMappedAddress();

        // Extract public IP and port from XOR-MAPPED-ADDRESS
        if (xorMappedAddr != null && !completer.isCompleted) {
          final ipVersion = isIPv6Socket ? IpVersion.v6 : IpVersion.v4;
          final response = (
            publicIp: xorMappedAddr.ip,
            publicPort: xorMappedAddr.port,
            ipVersion: ipVersion,
            transactionId: stunResponse.transactionId,
            raw: datagram.data,
            attrs: {'transactionId': stunResponse.transactionId},
          );

          // Format address correctly based on IP version
          final addressDisplay = ipVersion == IpVersion.v6
              ? '[${response.publicIp}]:${response.publicPort}'
              : '${response.publicIp}:${response.publicPort}';

          print(
            '[StunHandler] STUN response: $addressDisplay (${response.ipVersion.value})',
          );
          print(
            '[StunHandler] Port mapping: Local ${_socket.port} -> Public ${response.publicPort}',
          );

          subscription?.cancel();
          completer.complete(response);
        }
      }
    });

    // Timeout after 5 seconds if no response
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription?.cancel();
        throw TimeoutException('[StunHandler] STUN request timed out');
      },
    );
  }

  /// Pings the STUN server to verify connectivity
  @override
  Future<bool> pingStunServer() async {
    await performStunRequest();
    return true;
  }

  /// Retrieves the local IP address from network interfaces
  Future<String> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    // Find first non-loopback IPv4 address
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) {
          return addr.address;
        }
      }
    }

    // Fallback to loopback if no other address found
    return InternetAddress.loopbackIPv4.address;
  }
}
