import 'package:singleton_manager/singleton_manager.dart';

import '../types/stun_types.dart';
import 'i_dual_handler_facade.dart';
import 'i_dual_stun_handler.dart';
import 'i_stun_handler.dart';

/// Contract for the high-level STUN handler that manages dual IPv4/IPv6 stacks.
/// Extends [IValueForRegistry] so instances can be registered via [RegistryAccess].
abstract class IStunHandlerBase
    implements IDualHandlerFacade, IValueForRegistry {
  IDualStunHandler get dualHandler;

  Future<void> initialize({
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<void> initializeWithHandlers(
    IStunHandler ipv4Handler, {
    IStunHandler? ipv6Handler,
  });

  void setOnSocketRefreshIpv4(OnSocketRefreshIpv4 callback);
  void setOnSocketRefreshIpv6(OnSocketRefreshIpv6 callback);
  void removeOnSocketRefreshIpv4();
  void removeOnSocketRefreshIpv6();
}
