import 'dart:io';

import 'package:meta/meta.dart';

import '../../interfaces/dual/i_dual_stun_handler.dart';
import '../../interfaces/dual/i_dual_stun_handler_migratable.dart';
import '../../interfaces/dual/dual_stun_handler_profile.dart';
import '../../implementations/single/stun_handler_profile.dart';
import '../single/stun_handler_mixin.dart';
import 'dual_stun_handler_mixin.dart';

@internal
mixin DualStunHandlerMigratableMixin on DualStunHandlerMixin
    implements IDualStunHandlerMigratable {
  @override
  void migrateTo(
    IDualStunHandler stunHandler, {
    InternetAddressType type = InternetAddressType.IPv6,
  }) {
    final profile = _buildProfile();
    profile.applyTo(stunHandler, type: type);
  }

  DualStunHandlerProfile _buildProfile() {
    return DualStunHandlerProfile(
      ipv4: _profileFor(InternetAddressType.IPv4),
      ipv6: _profileFor(InternetAddressType.IPv6),
    );
  }

  StunHandlerProfile? _profileFor(InternetAddressType family) {
    final h = handler(type: family);
    if (h == null) return null;
    if (h is! StunHandlerMixin) return null;
    final mixin = h as StunHandlerMixin;

    return StunHandlerProfile(
      stunAddress: mixin.requestHandler.stunAddress,
      stunPort: mixin.requestHandler.stunPort,
      ipVersion: mixin.socketMgr.bindType,
      timeout: mixin.requestHandler.timeout,
      onLog: mixin.onLog,
    );
  }
}
