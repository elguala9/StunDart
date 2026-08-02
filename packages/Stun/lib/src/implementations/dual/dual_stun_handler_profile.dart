import 'dart:io';

import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/dual/i_dual_stun_handler_profile.dart';
import '../single/stun_handler_profile.dart';
import 'package:singleton_manager/singleton_manager.dart';

@dependencyInjectable
class DualStunHandlerProfile implements IDualStunHandlerProfile {
  DualStunHandlerProfile({
    this.ipv4,
    this.ipv6,
  });

  @override
  final StunHandlerProfile? ipv4;
  @override
  final StunHandlerProfile? ipv6;

  @override
  StunHandlerProfile? profileFor(InternetAddressType type) =>
      type == InternetAddressType.IPv4 ? ipv4 : ipv6;

  @override
  void applyTo(
    IDualStunHandler target, {
    InternetAddressType? type,
  }) {
    if (type == null) {
      _applyFamily(target, InternetAddressType.IPv6);
      _applyFamily(target, InternetAddressType.IPv4);
    } else {
      _applyFamily(target, type);
    }
  }

  void _applyFamily(IDualStunHandler target, InternetAddressType family) {
    final profile = profileFor(family);
    if (profile != null) {
      target.setStunServer(
        profile.stunAddress,
        profile.stunPort,
        type: family,
      );
    }
  }
}
