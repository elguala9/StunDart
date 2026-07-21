import '../../interfaces/dual/i_dual_stun_handler_migratable.dart';
import '../../mixins/dual/dual_stun_handler_migratable_mixin.dart';
import 'dual_stun_handler.dart';

class MigratableDualStunHandler extends DualStunHandler
    with DualStunHandlerMigratableMixin
    implements IDualStunHandlerMigratable {
  MigratableDualStunHandler() : super();
}
