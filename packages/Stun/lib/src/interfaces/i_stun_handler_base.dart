import 'dart:io';

import '../types/stun_types.dart';

/// Basic Stunhandler interface for normal and dual
abstract class IStunHandlerBase {
  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();
  Future<bool> pingStunServer();
  void setStunServer(String address, int port);
  void close();
  DateTime? get lastStunUpdated;
  DateTime? get lastLocalUpdated;
  RawDatagramSocket getSocket();
}
