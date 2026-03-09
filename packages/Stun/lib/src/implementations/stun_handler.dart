import 'dart:io';
import 'dart:async';

import 'package:callback_handler/callback_handler.dart';

import '/src/implementations/stun_config.dart';
import '/src/implementations/stun_message.dart';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';

/// STUN handler implementation with optional socket and auto-recreation
class StunHandler implements IStunHandler {
  /// Creates a STUN handler with the provided configuration (backward compatible)
  /// If socket is provided, it will be used; otherwise, socket must be created via factory
  StunHandler(
    StunHandlerInput input, {
    OnSocketRefresh? onSocketRefresh,
  })  : _socket = input.socket,
        _stunAddress = input.address ?? defaultStunConfig.address,
        _stunPort = input.port ?? defaultStunConfig.port,
        _bindType = input.socket?.address.type ?? InternetAddressType.IPv4,
        _bindPort = null,
        _timeout = const Duration(seconds: 5),
        _onLog = null {
    if (onSocketRefresh != null) {
      _socketRefreshHandler.register((data) {
        onSocketRefresh(data.$1, data.$2);
      });
    }
  }

  /// Named constructor for explicit socket ownership
  /// Creates a handler that manages an externally-provided socket
  StunHandler.withSocket(
    RawDatagramSocket socket, {
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  })  : _socket = socket,
        _stunAddress = address ?? defaultStunConfig.address,
        _stunPort = port ?? defaultStunConfig.port,
        _bindType = socket.address.type,
        _bindPort = null,
        _timeout = timeout,
        _onLog = onLog {
    if (onSocketRefresh != null) {
      _socketRefreshHandler.register((data) {
        onSocketRefresh(data.$1, data.$2);
      });
    }
  }

  /// Private constructor for factory use
  StunHandler._internal({
    String? stunAddress,
    int? stunPort,
    required InternetAddressType bindType,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  })  : _stunAddress = stunAddress ?? defaultStunConfig.address,
        _stunPort = stunPort ?? defaultStunConfig.port,
        _socket = null,
        _bindType = bindType,
        _bindPort = 0,
        _timeout = timeout,
        _onLog = onLog {
    if (onSocketRefresh != null) {
      _socketRefreshHandler.register((data) {
        onSocketRefresh(data.$1, data.$2);
      });
    }
  }

  /// STUN server address
  String _stunAddress = defaultStunConfig.address;

  /// STUN server port
  int _stunPort = defaultStunConfig.port;

  /// UDP socket for communication (nullable, can be recreated internally)
  RawDatagramSocket? _socket;

  /// IP version type used for binding the socket (for recreation)
  final InternetAddressType _bindType;

  /// Local port to bind to (for internal socket creation)
  final int? _bindPort;

  /// Cached STUN response (public IP and port)
  StunResponse? _cachedStunResponse;

  /// Cached local info (local IP and port)
  LocalInfo? _cachedLocalInfo;

  /// Timestamp of the last successful STUN request
  DateTime? _lastStunUpdated;

  /// Timestamp of the last successful local request
  DateTime? _lastLocalUpdated;

  /// Timeout for STUN requests
  final Duration _timeout;

  /// Optional logging callback
  final void Function(String)? _onLog;

  /// Socket refresh callback handler using callback_handler library
  final CallbackHandler<(StunResponse, StunResponse?), void> _socketRefreshHandler =
      CallbackHandler();

  /// Helper method to log messages
  void _log(String message) => _onLog?.call(message);

  /// Helper method to fire socket refresh callback
  void _fireSocketRefresh(StunResponse newResponse, StunResponse? oldResponse) {
    _socketRefreshHandler.invoke((newResponse, oldResponse));
  }

  /// Timestamp of the last successful STUN request
  @override
  DateTime? get lastStunUpdated => _lastStunUpdated;

  /// Timestamp of the last successful local request
  @override
  DateTime? get lastLocalUpdated => _lastLocalUpdated;

  /// Static factory to create StunHandler without an external socket
  /// Creates a new socket immediately during initialization
  static Future<StunHandler> withoutSocket({
    String? address,
    int? port,
    bool ipv6 = true,
    Duration timeout = const Duration(seconds: 5),
    void Function(String)? onLog,
    OnSocketRefresh? onSocketRefresh,
  }) async {
    final handler = StunHandler._internal(
      stunAddress: address,
      stunPort: port,
      bindType: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
      timeout: timeout,
      onLog: onLog,
      onSocketRefresh: onSocketRefresh,
    );
    // Create the socket immediately
    await handler._getSocket();
    return handler;
  }

  /// Performs a local network request to get local IP and port
  /// Returns cached result if available (doesn't change for same socket)
  @override
  Future<LocalInfo> performLocalRequest() async {
    if (_cachedLocalInfo != null) {
      return _cachedLocalInfo!;
    }

    final socket = await _getSocket();
    final localIp = await _getLocalIp();
    _cachedLocalInfo = (localIp: localIp, localPort: socket.port);
    _lastLocalUpdated = DateTime.now();
    return _cachedLocalInfo!;
  }

  /// Returns the underlying UDP socket
  /// Throws StateError if socket is not initialized
  @override
  RawDatagramSocket getSocket() {
    if (_socket == null) {
      throw StateError('Socket not yet initialized. Use StunHandler.create() for automatic socket management.');
    }
    return _socket!;
  }

  /// Closes the UDP socket
  @override
  void close() {
    _socket?.close();
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
  /// Returns cached result if available (doesn't change for same socket)
  /// Automatically handles socket recreation on network errors
  @override
  Future<StunResponse> performStunRequest() async {
    if (_cachedStunResponse != null) {
      return _cachedStunResponse!;
    }

    try {
      _cachedStunResponse = await _doStunRequest();
      _lastStunUpdated = DateTime.now();
      return _cachedStunResponse!;
    } on SocketException catch (e) {
      _log('[StunHandler] Socket error (${e.message}), attempting recreation...');
      final oldResponse = _cachedStunResponse;
      await _recreateSocket();
      _cachedStunResponse = await _doStunRequest();
      _lastStunUpdated = DateTime.now();
      _fireSocketRefresh(_cachedStunResponse!, oldResponse);
      return _cachedStunResponse!;
    } on OSError catch (e) {
      _log('[StunHandler] OS error (${e.message}), attempting recreation...');
      final oldResponse = _cachedStunResponse;
      await _recreateSocket();
      _cachedStunResponse = await _doStunRequest();
      _lastStunUpdated = DateTime.now();
      _fireSocketRefresh(_cachedStunResponse!, oldResponse);
      return _cachedStunResponse!;
    } on StateError catch (e) {
      // Handle "Stream has already been listened to" error
      if (e.message.contains('already been listened to')) {
        _log('[StunHandler] Stream error (socket already in use), attempting recreation...');
        final oldResponse = _cachedStunResponse;
        await _recreateSocket();
        _cachedStunResponse = await _doStunRequest();
        _lastStunUpdated = DateTime.now();
        _fireSocketRefresh(_cachedStunResponse!, oldResponse);
        return _cachedStunResponse!;
      }
      rethrow;
    }
  }

  /// Pings the STUN server to verify connectivity
  @override
  Future<bool> pingStunServer() async {
    await performStunRequest();
    return true;
  }

  /// Gets or lazily initializes the socket
  Future<RawDatagramSocket> _getSocket() async {
    if (_socket != null) {
      return _socket!;
    }

    // Create socket with appropriate bind address
    final bindAddr = _bindType == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4;

    _socket = await RawDatagramSocket.bind(bindAddr, _bindPort ?? 0, reuseAddress: true);
    _log('[StunHandler] Socket created: ${_socket!.address}:${_socket!.port}');
    return _socket!;
  }

  /// Resets cached values when socket changes
  void _resetCache() {
    _cachedStunResponse = null;
    _cachedLocalInfo = null;
    _lastStunUpdated = null;
    _lastLocalUpdated = null;
  }

  /// Recreates the socket (closes old, creates new)
  Future<void> _recreateSocket() async {
    _resetCache();
    _socket?.close();
    _socket = null;
    await _getSocket();
    _log('[StunHandler] Socket recreated with new port');
  }

  /// Core STUN request logic (extracted from performStunRequest for reusability)
  Future<StunResponse> _doStunRequest() async {
    final socket = await _getSocket();

    // Create STUN binding request message
    final request = StunMessage.createBindingRequest();
    final requestBytes = request.toBytes();

    // Determine IP version from socket
    final isIPv6Socket = socket.address.type == InternetAddressType.IPv6;

    // Log local socket info
    _log('[StunHandler] Local socket: ${socket.address}:${socket.port}');

    // Send request to STUN server
    final stunServerAddr = await InternetAddress.lookup(
      _stunAddress,
      type: isIPv6Socket ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
    );
    if (stunServerAddr.isEmpty) {
      throw StateError('Could not resolve STUN server address: $_stunAddress');
    }

    final targetAddr = stunServerAddr.first;
    _log('[StunHandler] Sending STUN request to $targetAddr:$_stunPort');

    socket.send(requestBytes, targetAddr, _stunPort);

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
      _timeout,
      onTimeout: () {
        subscription?.cancel();
        throw TimeoutException(
          '[StunHandler] STUN request timed out after ${_timeout.inSeconds}s');
      },
    );
  }

  /// Retrieves the local IP address from network interfaces
  Future<String> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: _bindType,
    );

    // Find first non-loopback address
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) {
          return addr.address;
        }
      }
    }

    // Fallback to loopback if no other address found
    return _bindType == InternetAddressType.IPv6
        ? InternetAddress.loopbackIPv6.address
        : InternetAddress.loopbackIPv4.address;
  }
}
