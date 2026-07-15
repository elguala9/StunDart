import 'dart:async';
import 'dart:io';

import '../../mixins/nat_detector_mixin.dart';
import '../../mixins/stun_logger_mixin.dart';
import '../../mixins/stun_server_resolver_mixin.dart';
import '../../types/stun_types.dart';

/// NAT Type Detector implementing RFC 5780 NAT Behavior Discovery
///
/// This class performs a series of STUN tests to determine the type of NAT
/// (Network Address Translation) that the client is behind.
///
/// Example:
/// ```dart
/// final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
/// final detector = NATDetector(
///   primaryServer: 'stun.l.google.com',
///   primaryPort: 19302,
///   socket: socket,
/// );
///
/// final result = await detector.detectNATType();
/// print('NAT Type: ${result.natType.displayName}');
/// socket.close();
/// ```
class NATDetector
    with StunLoggerMixin, StunServerResolverMixin, NATDetectorMixin {
  /// Creates a NAT detector
  ///
  /// - [primaryServer]: STUN server hostname or IP address
  /// - [primaryPort]: STUN server port (typically 3478 or 19302)
  /// - [socket]: UDP socket to use for communication
  /// - [timeout]: Maximum time to wait for each test response
  /// - [onLog]: Optional logging callback
  NATDetector({
    required this.primaryServer,
    required this.primaryPort,
    required this.socket,
    this.timeout = const Duration(seconds: 5),
    this.onLog,
  }) {
    // Convert to broadcast stream to allow multiple listeners
    socketStream = socket.asBroadcastStream();
  }

  @override
  final String primaryServer;

  @override
  final int primaryPort;

  @override
  final RawDatagramSocket socket;

  @override
  final Duration timeout;

  @override
  final void Function(String)? onLog;

  @override
  late final Stream<RawSocketEvent> socketStream;

  // Test results storage
  String? _publicIp1;
  int? _publicPort1;
  String? _alternateIp;
  int? _alternatePort;
  bool _rfc5780Supported = false;

  @override
  String? get publicIp1 => _publicIp1;

  @override
  int? get publicPort1 => _publicPort1;

  @override
  String? get alternateIp => _alternateIp;

  @override
  int? get alternatePort => _alternatePort;

  @override
  bool get rfc5780Supported => _rfc5780Supported;

  /// Stores the state discovered by Test 1 and returns a result reflecting
  /// the stored state (alternate address survives runs that don't find one).
  NATTestResult _recordTest1(NATTestResult result) {
    if (!result.success) return result;

    _publicIp1 = result.publicIp;
    _publicPort1 = result.publicPort;
    if (result.alternateIp != null) {
      _alternateIp = result.alternateIp;
      _alternatePort = result.alternatePort;
      _rfc5780Supported = result.rfc5780Supported;
    }

    return NATTestResult(
      success: true,
      publicIp: result.publicIp,
      publicPort: result.publicPort,
      alternateIp: _alternateIp,
      alternatePort: _alternatePort,
      rfc5780Supported: _rfc5780Supported,
    );
  }

  /// Perform full RFC 5780 NAT type detection
  ///
  /// This method executes a series of STUN tests to determine:
  /// - The type of NAT (Open Internet, Full Cone, Restricted Cone, etc.)
  /// - The filtering behavior (endpoint-independent vs dependent)
  /// - The mapping behavior (endpoint-independent vs dependent)
  ///
  /// Returns a [NATDetectionResult] with all detection information.
  Future<NATDetectionResult> detectNATType() async {
    final startTime = DateTime.now();
    final diagnostics = <String, dynamic>{};

    try {
      log('[NATDetector] Starting NAT type detection...');

      // Test 1: Basic binding request to primary server
      final test1Result = _recordTest1(await performTest1());
      diagnostics['test1'] = test1Result.toMap();

      if (!test1Result.success) {
        log('[NATDetector] Test 1 failed - UDP appears to be blocked');
        return buildResult(
          natType: NATType.udpBlocked,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      }

      log(
        '[NATDetector] Test 1 passed: ${test1Result.publicIp}:${test1Result.publicPort}',
      );

      // Test 2: Request from alternate IP/port (change-ip=true, change-port=true)
      final test2Result = await performTest2();
      diagnostics['test2'] = test2Result.toMap();

      if (test2Result.success) {
        log(
          '[NATDetector] Test 2 passed - checking if Open Internet or Full Cone',
        );
        // Received response from alternate address = Open Internet or Full Cone
        // Need to check if mapping changes to distinguish
        final test1bis = _recordTest1(await performTest1());
        diagnostics['test1bis'] = test1bis.toMap();

        if (test1bis.publicPort == _publicPort1) {
          log('[NATDetector] Mapping consistent - Full Cone NAT detected');
          return buildResult(
            natType: NATType.fullCone,
            filteringBehavior: NATFilteringBehavior.endpointIndependent,
            mappingBehavior: NATMappingBehavior.endpointIndependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        } else {
          log('[NATDetector] No NAT - Open Internet detected');
          return buildResult(
            natType: NATType.openInternet,
            filteringBehavior: NATFilteringBehavior.endpointIndependent,
            mappingBehavior: NATMappingBehavior.endpointIndependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        }
      }

      log('[NATDetector] Test 2 filtered - NAT is present');

      // Test 3: Request to alternate server address (if OTHER-ADDRESS available)
      if (_alternateIp != null && _alternatePort != null) {
        log('[NATDetector] Running Test 3 to alternate server...');
        final test3Result = await performTest3();
        diagnostics['test3'] = test3Result.toMap();

        if (test3Result.success && test3Result.publicPort != _publicPort1) {
          // Mapping changed = Symmetric NAT
          log('[NATDetector] Port mapping changed - Symmetric NAT detected');
          return buildResult(
            natType: NATType.symmetric,
            filteringBehavior: NATFilteringBehavior.addressAndPortDependent,
            mappingBehavior: NATMappingBehavior.addressAndPortDependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        }
      } else {
        log('[NATDetector] No alternate server available, skipping Test 3');
        diagnostics['test3'] = {
          'skipped': true,
          'reason': 'No alternate address',
        };
      }

      // Test 4: Request from alternate port only (change-port=true)
      log('[NATDetector] Running Test 4 (change port only)...');
      final test4Result = await performTest4();
      diagnostics['test4'] = test4Result.toMap();

      if (test4Result.success) {
        log('[NATDetector] Test 4 passed - Restricted Cone NAT detected');
        return buildResult(
          natType: NATType.restrictedCone,
          filteringBehavior: NATFilteringBehavior.addressDependent,
          mappingBehavior: NATMappingBehavior.endpointIndependent,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      } else {
        log(
          '[NATDetector] Test 4 filtered - Port Restricted Cone NAT detected',
        );
        return buildResult(
          natType: NATType.portRestrictedCone,
          filteringBehavior: NATFilteringBehavior.addressAndPortDependent,
          mappingBehavior: NATMappingBehavior.endpointIndependent,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      }
    } catch (e) {
      log('[NATDetector] Error during detection: $e');
      diagnostics['error'] = e.toString();
      return buildResult(
        natType: NATType.udpBlocked,
        detectionTime: DateTime.now().difference(startTime),
        diagnostics: diagnostics,
      );
    }
  }
}
