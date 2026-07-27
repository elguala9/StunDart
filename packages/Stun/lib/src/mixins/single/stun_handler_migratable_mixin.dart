import 'package:meta/meta.dart';

import '../../interfaces/single/i_stun_handler.dart';
import '../../interfaces/single/i_stun_handler_migratable.dart';
import '../../implementations/single/stun_handler_profile.dart';
import 'stun_handler_mixin.dart';
import 'stun_logger_mixin.dart';

@internal
mixin StunHandlerMigratableMixin on StunHandlerMixin, StunLoggerMixin
    implements IStunHandlerMigratable {
  @override
  void migrateTo(IStunHandler stunHandler) {
    final profile = StunHandlerProfile(
      stunAddress: requestHandler.stunAddress,
      stunPort: requestHandler.stunPort,
      ipVersion: socketMgr.bindType,
      timeout: requestHandler.timeout,
      onLog: onLog,
    );

    profile.applyTo(stunHandler);
  }
}
