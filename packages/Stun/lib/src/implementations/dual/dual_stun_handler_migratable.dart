import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';

import '../../mixins/dual/dual_stun_handler_migratable_mixin.dart';

class DualStunHandlerMigratable extends DualStunHandler
    with DualStunHandlerMigratableMixin
    implements IDualStunHandlerMigratable {
  DualStunHandlerMigratable({
    @Subkey('ipv4') IStunHandlerMigratable? ipv4Handler,
    @Subkey('ipv6') IStunHandlerMigratable? ipv6Handler,
  }) : super(ipv4Handler: ipv4Handler, ipv6Handler: ipv6Handler);
}
