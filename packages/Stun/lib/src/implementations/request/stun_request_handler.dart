import 'dart:io';
import 'dart:async';

import './stun_message.dart';
import '../../types/stun_types.dart';

/// Handles core STUN request/response logic
class StunRequestHandler {
  StunRequestHandler({
    required this.stunAddress,
    required this.stunPort,
    required this.timeout,
    this.onLog,
  });

  final String stunAddress;
  final int stunPort;
  final Duration timeout;
  final void Function(String)? onLog;

  /// Helper to log messages
  void _log(String message) => onLog?.call(message);

  /// Core STUN request logic
  Future<StunResponse> performStunRequest(RawDatagramSocket socket) async {
    // Create STUN binding request message
    final request = StunMessage.createBindingRequest();
    final requestBytes = request.toBytes();

    // Determine IP version from socket
    final isIPv6Socket = socket.address.type == InternetAddressType.IPv6;

    // Log local socket info
    _log('[StunHandler] Local socket: ${socket.address}:${socket.port}');

    // Send request to STUN server
    final stunServerAddr = await InternetAddress.lookup(
      stunAddress,
      type: isIPv6Socket ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
    );
    if (stunServerAddr.isEmpty) {
      throw StateError('Could not resolve STUN server address: $stunAddress');
    }

    final targetAddr = stunServerAddr.first;
    _log('[StunHandler] Sending STUN request to $targetAddr:$stunPort');

    socket.send(requestBytes, targetAddr, stunPort);

    final completer = Completer<StunResponse>();

    // Listen for response from STUN server
    StreamSubscription<RawSocketEvent>? subscription;
    subscription = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
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

          _log(
            '[StunHandler] STUN response: $addressDisplay (${response.ipVersion.value})',
          );
          _log(
            '[StunHandler] Port mapping: Local ${socket.port} -> Public ${response.publicPort}',
          );

          subscription?.cancel();
          completer.complete(response);
        }
      }
    });

    // Timeout after configured duration if no response
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription?.cancel();
        throw TimeoutException(
          '[StunHandler] STUN request timed out after ${timeout.inSeconds}s');
      },
    );
  }
}
