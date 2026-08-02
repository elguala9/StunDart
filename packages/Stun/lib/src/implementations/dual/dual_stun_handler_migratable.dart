import '../../interfaces/dual/i_dual_stun_handler_migratable.dart';
import '../../mixins/dual/dual_stun_handler_migratable_mixin.dart';
import 'dual_stun_handler.dart';
import 'package:singleton_manager/singleton_manager.dart';

@dependencyInjectable
class DualStunHandlerMigratable extends DualStunHandler
    with DualStunHandlerMigratableMixin
    implements IDualStunHandlerMigratable {
  DualStunHandlerMigratable() : super();
}
