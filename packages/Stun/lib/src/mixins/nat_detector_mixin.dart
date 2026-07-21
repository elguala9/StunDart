import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import '../implementations/request/stun_message.dart';
import '../types/stun_types.dart';
import 'stun_logger_mixin.dart';
import 'stun_server_resolver_mixin.dart';

/// Internal result of a single NAT detection test.
@internal
class NATTestResult {
  NATTestResult({
    required this.success,
    this.publicIp,
    this.publicPort,
    this.alternateIp,
    this.alternatePort,
    this.rfc5780Supported = false,
    this.error,
  });

  final bool success;
  final String? publicIp;
  final int? publicPort;
  final String? alternateIp;
  final int? alternatePort;
  final bool rfc5780Supported;
  final String? error;

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      if (publicIp != null) 'publicIp': publicIp,
      if (publicPort != null) 'publicPort': publicPort,
      if (alternateIp != null) 'alternateIp': alternateIp,
      if (alternatePort != null) 'alternatePort': alternatePort,
      if (error != null) 'error': error,
    };
  }
}

/// Internal-only behavior of `NATDetector`: RFC 5780 test primitives, STUN
/// message exchange and result building. The mixing class provides the
/// configuration and test-state storage. Not part of the package's public
/// API — do not export it from `stun.dart`.
@internal
mixin NATDetectorMixin on StunLoggerMixin, StunServerResolverMixin {
  /// UDP socket provided by the mixing class.
  RawDatagramSocket get socket;

  /// Broadcast stream of socket events provided by the mixing class.
  Stream<RawSocketEvent> get socketStream;

  /// Per-test timeout provided by the mixing class.
  Duration get timeout;

  /// Primary STUN server hostname provided by the mixing class.
  String get primaryServer;

  /// Primary STUN server port provided by the mixing class.
  int get primaryPort;

  /// Optional secondary STUN server hostname used as Test 3 fallback when
  /// the primary server does not advertise an alternate address.
  String? get secondaryServer;

  /// Port of the optional secondary STUN server.
  int? get secondaryPort;

  /// Public IP discovered by Test 1 (stored by the mixing class).
  String? get publicIp1;

  /// Public port discovered by Test 1 (stored by the mixing class).
  int? get publicPort1;

  /// Alternate server IP discovered by Test 1 (stored by the mixing class).
  String? get alternateIp;

  /// Alternate server port discovered by Test 1 (stored by the mixing class).
  int? get alternatePort;

  /// Whether the server supports RFC 5780 (stored by the mixing class).
  bool get rfc5780Supported;

  bool get _isIPv6Socket => socket.address.type == InternetAddressType.IPv6;

  /// Test 1: Normal binding request to primary server
  Future<NATTestResult> performTest1() async {
    try {
      final request = StunMessage.createBindingRequest();
      final serverAddr = await resolveStunServer(
        primaryServer,
        ipv6: _isIPv6Socket,
      );

      final response = await sendAndReceive(
        serverAddr: serverAddr,
        serverPort: primaryPort,
        request: request,
      );

      if (response == null) {
        return NATTestResult(success: false, error: 'No response');
      }

      final mappedAddr = response.getXorMappedAddress();
      if (mappedAddr == null) {
        return NATTestResult(success: false, error: 'No XOR-MAPPED-ADDRESS');
      }

      String? testAlternateIp;
      int? testAlternatePort;
      var testRfc5780Supported = false;

      // Try to get alternate server address (RFC 5780)
      final otherAddr = response.getOtherAddress();
      if (otherAddr != null) {
        testAlternateIp = otherAddr.ip;
        testAlternatePort = otherAddr.port;
        testRfc5780Supported = true;
      } else {
        // Fallback to RFC 3489 CHANGED-ADDRESS
        final changedAddr = response.getChangedAddress();
        if (changedAddr != null) {
          testAlternateIp = changedAddr.ip;
          testAlternatePort = changedAddr.port;
          testRfc5780Supported = false;
        }
      }

      return NATTestResult(
        success: true,
        publicIp: mappedAddr.ip,
        publicPort: mappedAddr.port,
        alternateIp: testAlternateIp,
        alternatePort: testAlternatePort,
        rfc5780Supported: testRfc5780Supported,
      );
    } catch (e) {
      return NATTestResult(success: false, error: e.toString());
    }
  }

  /// Test 2: Request with CHANGE-REQUEST (IP + Port)
  Future<NATTestResult> performTest2() async {
    try {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: true,
      );
      final serverAddr = await resolveStunServer(
        primaryServer,
        ipv6: _isIPv6Socket,
      );

      final response = await sendAndReceive(
        serverAddr: serverAddr,
        serverPort: primaryPort,
        request: request,
      );

      if (response == null) {
        return NATTestResult(success: false, error: 'Filtered or timeout');
      }

      final mappedAddr = response.getXorMappedAddress();
      return NATTestResult(
        success: true,
        publicIp: mappedAddr?.ip,
        publicPort: mappedAddr?.port,
      );
    } catch (e) {
      return NATTestResult(success: false, error: e.toString());
    }
  }

  /// Test 3: Request to alternate server
  ///
  /// Targets the alternate address advertised by the primary server
  /// (OTHER-ADDRESS/CHANGED-ADDRESS). When none is available, falls back to
  /// the configured [secondaryServer], if any.
  Future<NATTestResult> performTest3() async {
    try {
      final InternetAddress serverAddr;
      final int serverPort;

      if (alternateIp != null && alternatePort != null) {
        serverAddr = InternetAddress(alternateIp!);
        serverPort = alternatePort!;
      } else if (secondaryServer != null && secondaryPort != null) {
        serverAddr = await resolveStunServer(
          secondaryServer!,
          ipv6: _isIPv6Socket,
        );
        final primaryAddr = await resolveStunServer(
          primaryServer,
          ipv6: _isIPv6Socket,
        );
        if (serverAddr.address == primaryAddr.address &&
            secondaryPort == primaryPort) {
          return NATTestResult(
            success: false,
            error: 'Secondary server resolves to the same endpoint as primary',
          );
        }
        serverPort = secondaryPort!;
      } else {
        return NATTestResult(success: false, error: 'No alternate server');
      }

      final request = StunMessage.createBindingRequest();

      final response = await sendAndReceive(
        serverAddr: serverAddr,
        serverPort: serverPort,
        request: request,
      );

      if (response == null) {
        return NATTestResult(
          success: false,
          error: 'No response from alternate',
        );
      }

      final mappedAddr = response.getXorMappedAddress();
      if (mappedAddr == null) {
        return NATTestResult(success: false, error: 'No XOR-MAPPED-ADDRESS');
      }

      return NATTestResult(
        success: true,
        publicIp: mappedAddr.ip,
        publicPort: mappedAddr.port,
      );
    } catch (e) {
      return NATTestResult(success: false, error: e.toString());
    }
  }

  /// Test 4: Request with CHANGE-REQUEST (Port only)
  Future<NATTestResult> performTest4() async {
    try {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: false,
        changePort: true,
      );
      final serverAddr = await resolveStunServer(
        primaryServer,
        ipv6: _isIPv6Socket,
      );

      final response = await sendAndReceive(
        serverAddr: serverAddr,
        serverPort: primaryPort,
        request: request,
      );

      if (response == null) {
        return NATTestResult(success: false, error: 'Filtered or timeout');
      }

      final mappedAddr = response.getXorMappedAddress();
      return NATTestResult(
        success: true,
        publicIp: mappedAddr?.ip,
        publicPort: mappedAddr?.port,
      );
    } catch (e) {
      return NATTestResult(success: false, error: e.toString());
    }
  }

  /// Send a STUN request and wait for response
  Future<StunMessage?> sendAndReceive({
    required InternetAddress serverAddr,
    required int serverPort,
    required StunMessage request,
  }) async {
    final requestBytes = request.toBytes();
    socket.send(requestBytes, serverAddr, serverPort);

    final completer = Completer<StunMessage?>();
    StreamSubscription<RawSocketEvent>? subscription;

    subscription = socketStream.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram == null) return;

        try {
          final response = StunMessage.fromBytes(datagram.data);

          // Verify transaction ID matches
          bool transactionIdMatches = true;
          for (var i = 0; i < 12; i++) {
            if (response.transactionId[i] != request.transactionId[i]) {
              transactionIdMatches = false;
              break;
            }
          }

          if (transactionIdMatches && !completer.isCompleted) {
            subscription?.cancel();
            completer.complete(response);
          }
        } catch (e) {
          // Ignore parsing errors (could be unrelated UDP traffic)
        }
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription?.cancel();
        return null;
      },
    );
  }

  /// Build final detection result
  NATDetectionResult buildResult({
    required NATType natType,
    NATFilteringBehavior filteringBehavior = NATFilteringBehavior.unknown,
    NATMappingBehavior mappingBehavior = NATMappingBehavior.unknown,
    required Duration detectionTime,
    required Map<String, dynamic> diagnostics,
  }) {
    return (
      natType: natType,
      filteringBehavior: filteringBehavior,
      mappingBehavior: mappingBehavior,
      publicIp: publicIp1,
      publicPort: publicPort1,
      alternateIp: alternateIp,
      alternatePort: alternatePort,
      rfc5780Supported: rfc5780Supported,
      detectionTime: detectionTime,
      diagnostics: diagnostics,
    );
  }
}
