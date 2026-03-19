import 'dart:io';
import 'dart:async';

import '../request/stun_message.dart';
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
class NATDetector {
  /// Creates a NAT detector
  ///
  /// - [primaryServer]: STUN server hostname or IP address
  /// - [primaryPort]: STUN server port (typically 3478 or 19302)
  /// - [socket]: UDP socket to use for communication
  /// - [timeout]: Maximum time to wait for each test response
  NATDetector({
    required String primaryServer,
    required int primaryPort,
    required RawDatagramSocket socket,
    Duration timeout = const Duration(seconds: 5),
  }) : _primaryServer = primaryServer,
       _primaryPort = primaryPort,
       _socket = socket,
       _timeout = timeout {
    // Convert to broadcast stream to allow multiple listeners
    _socketStream = _socket.asBroadcastStream();
  }

  final String _primaryServer;
  final int _primaryPort;
  final RawDatagramSocket _socket;
  final Duration _timeout;
  late final Stream<RawSocketEvent> _socketStream;

  // Test results storage
  String? _publicIp1;
  int? _publicPort1;
  String? _alternateIp;
  int? _alternatePort;
  bool _rfc5780Supported = false;

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
      print('[NATDetector] Starting NAT type detection...');

      // Test 1: Basic binding request to primary server
      final test1Result = await _performTest1();
      diagnostics['test1'] = test1Result.toMap();

      if (!test1Result.success) {
        print('[NATDetector] Test 1 failed - UDP appears to be blocked');
        return _buildResult(
          natType: NATType.udpBlocked,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      }

      print(
        '[NATDetector] Test 1 passed: ${test1Result.publicIp}:${test1Result.publicPort}',
      );

      // Test 2: Request from alternate IP/port (change-ip=true, change-port=true)
      final test2Result = await _performTest2();
      diagnostics['test2'] = test2Result.toMap();

      if (test2Result.success) {
        print(
          '[NATDetector] Test 2 passed - checking if Open Internet or Full Cone',
        );
        // Received response from alternate address = Open Internet or Full Cone
        // Need to check if mapping changes to distinguish
        final test1bis = await _performTest1();
        diagnostics['test1bis'] = test1bis.toMap();

        if (test1bis.publicPort == _publicPort1) {
          print('[NATDetector] Mapping consistent - Full Cone NAT detected');
          return _buildResult(
            natType: NATType.fullCone,
            filteringBehavior: NATFilteringBehavior.endpointIndependent,
            mappingBehavior: NATMappingBehavior.endpointIndependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        } else {
          print('[NATDetector] No NAT - Open Internet detected');
          return _buildResult(
            natType: NATType.openInternet,
            filteringBehavior: NATFilteringBehavior.endpointIndependent,
            mappingBehavior: NATMappingBehavior.endpointIndependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        }
      }

      print('[NATDetector] Test 2 filtered - NAT is present');

      // Test 3: Request to alternate server address (if OTHER-ADDRESS available)
      if (_alternateIp != null && _alternatePort != null) {
        print('[NATDetector] Running Test 3 to alternate server...');
        final test3Result = await _performTest3();
        diagnostics['test3'] = test3Result.toMap();

        if (test3Result.success && test3Result.publicPort != _publicPort1) {
          // Mapping changed = Symmetric NAT
          print('[NATDetector] Port mapping changed - Symmetric NAT detected');
          return _buildResult(
            natType: NATType.symmetric,
            filteringBehavior: NATFilteringBehavior.addressAndPortDependent,
            mappingBehavior: NATMappingBehavior.addressAndPortDependent,
            detectionTime: DateTime.now().difference(startTime),
            diagnostics: diagnostics,
          );
        }
      } else {
        print('[NATDetector] No alternate server available, skipping Test 3');
        diagnostics['test3'] = {
          'skipped': true,
          'reason': 'No alternate address',
        };
      }

      // Test 4: Request from alternate port only (change-port=true)
      print('[NATDetector] Running Test 4 (change port only)...');
      final test4Result = await _performTest4();
      diagnostics['test4'] = test4Result.toMap();

      if (test4Result.success) {
        print('[NATDetector] Test 4 passed - Restricted Cone NAT detected');
        return _buildResult(
          natType: NATType.restrictedCone,
          filteringBehavior: NATFilteringBehavior.addressDependent,
          mappingBehavior: NATMappingBehavior.endpointIndependent,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      } else {
        print(
          '[NATDetector] Test 4 filtered - Port Restricted Cone NAT detected',
        );
        return _buildResult(
          natType: NATType.portRestrictedCone,
          filteringBehavior: NATFilteringBehavior.addressAndPortDependent,
          mappingBehavior: NATMappingBehavior.endpointIndependent,
          detectionTime: DateTime.now().difference(startTime),
          diagnostics: diagnostics,
        );
      }
    } catch (e) {
      print('[NATDetector] Error during detection: $e');
      diagnostics['error'] = e.toString();
      return _buildResult(
        natType: NATType.udpBlocked,
        detectionTime: DateTime.now().difference(startTime),
        diagnostics: diagnostics,
      );
    }
  }

  /// Test 1: Normal binding request to primary server
  Future<_TestResult> _performTest1() async {
    try {
      final request = StunMessage.createBindingRequest();
      final serverAddr = await _resolveServer(_primaryServer);

      final response = await _sendAndReceive(
        serverAddr: serverAddr,
        serverPort: _primaryPort,
        request: request,
      );

      if (response == null) {
        return _TestResult(success: false, error: 'No response');
      }

      final mappedAddr = response.getXorMappedAddress();
      if (mappedAddr == null) {
        return _TestResult(success: false, error: 'No XOR-MAPPED-ADDRESS');
      }

      // Store public IP and port
      _publicIp1 = mappedAddr.ip;
      _publicPort1 = mappedAddr.port;

      // Try to get alternate server address (RFC 5780)
      final otherAddr = response.getOtherAddress();
      if (otherAddr != null) {
        _alternateIp = otherAddr.ip;
        _alternatePort = otherAddr.port;
        _rfc5780Supported = true;
      } else {
        // Fallback to RFC 3489 CHANGED-ADDRESS
        final changedAddr = response.getChangedAddress();
        if (changedAddr != null) {
          _alternateIp = changedAddr.ip;
          _alternatePort = changedAddr.port;
          _rfc5780Supported = false;
        }
      }

      return _TestResult(
        success: true,
        publicIp: mappedAddr.ip,
        publicPort: mappedAddr.port,
        alternateIp: _alternateIp,
        alternatePort: _alternatePort,
      );
    } catch (e) {
      return _TestResult(success: false, error: e.toString());
    }
  }

  /// Test 2: Request with CHANGE-REQUEST (IP + Port)
  Future<_TestResult> _performTest2() async {
    try {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: true,
        changePort: true,
      );
      final serverAddr = await _resolveServer(_primaryServer);

      final response = await _sendAndReceive(
        serverAddr: serverAddr,
        serverPort: _primaryPort,
        request: request,
      );

      if (response == null) {
        return _TestResult(success: false, error: 'Filtered or timeout');
      }

      final mappedAddr = response.getXorMappedAddress();
      return _TestResult(
        success: true,
        publicIp: mappedAddr?.ip,
        publicPort: mappedAddr?.port,
      );
    } catch (e) {
      return _TestResult(success: false, error: e.toString());
    }
  }

  /// Test 3: Request to alternate server
  Future<_TestResult> _performTest3() async {
    if (_alternateIp == null || _alternatePort == null) {
      return _TestResult(success: false, error: 'No alternate server');
    }

    try {
      final request = StunMessage.createBindingRequest();
      final serverAddr = InternetAddress(_alternateIp!);

      final response = await _sendAndReceive(
        serverAddr: serverAddr,
        serverPort: _alternatePort!,
        request: request,
      );

      if (response == null) {
        return _TestResult(success: false, error: 'No response from alternate');
      }

      final mappedAddr = response.getXorMappedAddress();
      if (mappedAddr == null) {
        return _TestResult(success: false, error: 'No XOR-MAPPED-ADDRESS');
      }

      return _TestResult(
        success: true,
        publicIp: mappedAddr.ip,
        publicPort: mappedAddr.port,
      );
    } catch (e) {
      return _TestResult(success: false, error: e.toString());
    }
  }

  /// Test 4: Request with CHANGE-REQUEST (Port only)
  Future<_TestResult> _performTest4() async {
    try {
      final request = StunMessage.createBindingRequestWithChangeRequest(
        changeIp: false,
        changePort: true,
      );
      final serverAddr = await _resolveServer(_primaryServer);

      final response = await _sendAndReceive(
        serverAddr: serverAddr,
        serverPort: _primaryPort,
        request: request,
      );

      if (response == null) {
        return _TestResult(success: false, error: 'Filtered or timeout');
      }

      final mappedAddr = response.getXorMappedAddress();
      return _TestResult(
        success: true,
        publicIp: mappedAddr?.ip,
        publicPort: mappedAddr?.port,
      );
    } catch (e) {
      return _TestResult(success: false, error: e.toString());
    }
  }

  /// Send a STUN request and wait for response
  Future<StunMessage?> _sendAndReceive({
    required InternetAddress serverAddr,
    required int serverPort,
    required StunMessage request,
  }) async {
    final requestBytes = request.toBytes();
    _socket.send(requestBytes, serverAddr, serverPort);

    final completer = Completer<StunMessage?>();
    StreamSubscription<RawSocketEvent>? subscription;

    subscription = _socketStream.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket.receive();
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
      _timeout,
      onTimeout: () {
        subscription?.cancel();
        return null;
      },
    );
  }

  /// Resolve server hostname to IP address
  Future<InternetAddress> _resolveServer(String hostname) async {
    final isIPv6Socket = _socket.address.type == InternetAddressType.IPv6;
    final addresses = await InternetAddress.lookup(
      hostname,
      type: isIPv6Socket ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
    );

    if (addresses.isEmpty) {
      throw StateError('Could not resolve server: $hostname');
    }

    return addresses.first;
  }

  /// Build final detection result
  NATDetectionResult _buildResult({
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
      publicIp: _publicIp1,
      publicPort: _publicPort1,
      alternateIp: _alternateIp,
      alternatePort: _alternatePort,
      rfc5780Supported: _rfc5780Supported,
      detectionTime: detectionTime,
      diagnostics: diagnostics,
    );
  }
}

/// Internal test result
class _TestResult {
  _TestResult({
    required this.success,
    this.publicIp,
    this.publicPort,
    this.alternateIp,
    this.alternatePort,
    this.error,
  });

  final bool success;
  final String? publicIp;
  final int? publicPort;
  final String? alternateIp;
  final int? alternatePort;
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
