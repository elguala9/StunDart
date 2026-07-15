import 'dart:io';
import 'dart:async';

import './stun_message.dart';
import '../../mixins/stun_logger_mixin.dart';
import '../../mixins/stun_server_resolver_mixin.dart';
import '../../types/stun_types.dart';

/// Handles core STUN request/response logic
class StunRequestHandler with StunLoggerMixin, StunServerResolverMixin {
  StunRequestHandler({
    required this.stunAddress,
    required this.stunPort,
    required this.timeout,
    this.onLog,
  });

  final String stunAddress;
  final int stunPort;
  final Duration timeout;

  @override
  final void Function(String)? onLog;

  /// Core STUN request logic
  Future<StunResponse> performStunRequest(RawDatagramSocket socket) async {
    // Create STUN binding request message
    final request = StunMessage.createBindingRequest();
    final requestBytes = request.toBytes();

    // Determine IP version from socket
    final isIPv6Socket = socket.address.type == InternetAddressType.IPv6;

    // Log local socket info
    log('[StunHandler] Local socket: ${socket.address}:${socket.port}');

    // Send request to STUN server
    final targetAddr = await resolveStunServer(stunAddress, ipv6: isIPv6Socket);
    log('[StunHandler] Sending STUN request to $targetAddr:$stunPort');

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

          log(
            '[StunHandler] STUN response: $addressDisplay (${response.ipVersion.value})',
          );
          log(
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
          '[StunHandler] STUN request timed out after ${timeout.inSeconds}s',
        );
      },
    );
  }
}
