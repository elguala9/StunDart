import 'dart:io';

import '../single/i_stun_handler.dart';

abstract class IStunHandlerProfile {
  String get stunAddress;
  int get stunPort;
  InternetAddressType get ipVersion;
  Duration get timeout;
  void Function(String)? get onLog;

  void applyTo(IStunHandler target);
}
