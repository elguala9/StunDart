import 'dart:io';

import '../single/i_stun_handler_profile.dart';
import '../dual/i_dual_stun_handler.dart';

abstract class IDualStunHandlerProfile {
  IStunHandlerProfile? get ipv4;
  IStunHandlerProfile? get ipv6;

  IStunHandlerProfile? profileFor(InternetAddressType type);
  void applyTo(IDualStunHandler target, {InternetAddressType? type});
}
