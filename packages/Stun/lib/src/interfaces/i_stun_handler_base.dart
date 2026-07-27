import 'dart:io';

import 'package:singleton_manager/singleton_manager.dart';

import '../types/stun_types.dart';

/// Basic Stunhandler interface for normal and dual
abstract class IStunHandlerBase implements IValueForRegistry {
  Future<StunResponse> performStunRequest();
  Future<LocalInfo> performLocalRequest();
  Future<bool> pingStunServer();
  void setStunServer(String address, int port);
  void close();
  DateTime? get lastStunUpdated;
  DateTime? get lastLocalUpdated;
  RawDatagramSocket getSocket();
}
