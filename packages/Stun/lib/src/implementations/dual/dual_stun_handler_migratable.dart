import 'package:singleton_manager/singleton_manager.dart';
import 'package:stun/stun.dart';

import '../../mixins/dual/dual_stun_handler_migratable_mixin.dart';

@dependencyInjectable
class DualStunHandlerMigratable extends DualStunHandler
    with DualStunHandlerMigratableMixin
    implements IDualStunHandlerMigratable {
  DualStunHandlerMigratable({
    @Subkey('ipv4') IStunHandlerMigratable? ipv4Handler,
    @Subkey('ipv6') IStunHandlerMigratable? ipv6Handler,
  }) : super(ipv4Handler: ipv4Handler, ipv6Handler: ipv6Handler);

  // ignore: avoid_unused_constructor_parameters, // GENERATED CODE - DO NOT MODIFY BY HAND
  factory DualStunHandlerMigratable.dependencyInjectionFactory({String key = 'default', String subkey = 'default'}) { // GENERATED CODE - DO NOT MODIFY BY HAND
    final ipv4Handler = RegistryManager.instance.getInstanceNullable<IStunHandlerMigratable>(key: key, subkey: 'ipv4'); // GENERATED CODE - DO NOT MODIFY BY HAND
    final ipv6Handler = RegistryManager.instance.getInstanceNullable<IStunHandlerMigratable>(key: key, subkey: 'ipv6'); // GENERATED CODE - DO NOT MODIFY BY HAND

    return DualStunHandlerMigratable( // GENERATED CODE - DO NOT MODIFY BY HAND
      ipv4Handler: ipv4Handler, // GENERATED CODE - DO NOT MODIFY BY HAND
      ipv6Handler: ipv6Handler, // GENERATED CODE - DO NOT MODIFY BY HAND
    ); // GENERATED CODE - DO NOT MODIFY BY HAND
  } // GENERATED CODE - DO NOT MODIFY BY HAND
}
