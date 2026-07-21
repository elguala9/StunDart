import 'dart:io';

import '../single/i_stun_handler.dart';
import '../../types/stun_types.dart';

abstract class IStunHandlerProfile {
  String get stunAddress;
  int get stunPort;
  List<OnSocketRefresh> get callbacks;
  InternetAddressType get ipVersion;
  Duration get timeout;
  void Function(String)? get onLog;

  void applyTo(IStunHandler target);
}
