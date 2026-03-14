import 'dart:io';
import 'package:singleton_manager/singleton_manager.dart';

import '../types/stun_types.dart';

/// Interface for STUN handler
abstract class IStunHandler implements IValueForRegistry {
  /// Performs a STUN request and returns the public (IP, port) inferred by the server
  Future<StunResponse> performStunRequest();

  /// Retrieves local (IP, port) information without contacting the STUN server
  Future<LocalInfo> performLocalRequest();

  /// Verifies the reachability of the configured STUN server
  Future<bool> pingStunServer();

  /// Sets the STUN server address/port used for subsequent requests
  void setStunServer(String address, int port);

  /// Returns the underlying socket used to communicate with the STUN server
  RawDatagramSocket getSocket();

  /// Closes the socket and releases resources held by the STUN handler
  void close();

  /// Timestamp of the last successful STUN request (null if never performed)
  DateTime? get lastStunUpdated;

  /// Timestamp of the last successful local request (null if never performed)
  DateTime? get lastLocalUpdated;

  /// Registers a callback to be fired when socket is recreated after network error
  void addOnSocketRefresh(OnSocketRefresh callback);

  /// Unregisters a previously added socket refresh callback
  void removeOnSocketRefresh(OnSocketRefresh callback);
}
