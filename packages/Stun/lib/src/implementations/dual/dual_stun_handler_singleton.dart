import '../../interfaces/dual/i_dual_stun_handler_singleton.dart';
import 'dual_stun_handler_base.dart';
import 'package:singleton_manager/singleton_manager.dart';

@dependencyInjectable
/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class DualStunHandlerSingleton extends DualStunHandlerBase
    implements IDualStunHandlerSingleton {
  factory DualStunHandlerSingleton() => _instance;
  DualStunHandlerSingleton._internal() : super();

  static final DualStunHandlerSingleton _instance =
      DualStunHandlerSingleton._internal();
  static DualStunHandlerSingleton get instance => _instance;
}
