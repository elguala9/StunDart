import 'dart:io';

import '../single/i_stun_handler_profile.dart';
import '../dual/i_dual_stun_handler.dart';
import '../../types/stun_types.dart';

abstract class IDualStunHandlerProfile {
  IStunHandlerProfile? get ipv4;
  IStunHandlerProfile? get ipv6;
  List<OnSocketRefresh> get ipv4Callbacks;
  List<OnSocketRefresh> get ipv6Callbacks;

  List<OnSocketRefresh> callbacksFor(InternetAddressType type);
  IStunHandlerProfile? profileFor(InternetAddressType type);
  void applyTo(IDualStunHandler target, {InternetAddressType? type});
}
