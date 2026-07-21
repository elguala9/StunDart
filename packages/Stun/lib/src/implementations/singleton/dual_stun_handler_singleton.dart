import 'package:singleton_manager/singleton_manager.dart';

import '../../interfaces/i_dual_stun_handler_singleton.dart';
import 'dual_stun_handler_base.dart';
import 'singleton_handler_factory.dart';

/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class DualStunHandlerSingleton extends DualStunHandlerBase
    implements IDualStunHandlerSingleton {
  factory DualStunHandlerSingleton() => _instance;
  DualStunHandlerSingleton._internal() : super();

  static final DualStunHandlerSingleton _instance =
      DualStunHandlerSingleton._internal();
  static DualStunHandlerSingleton get instance => _instance;

  @override
  Future<void> initializeDI() async {
    if (dualHandler.getHandler(ipv6: false) == null) {
      throw StateError(
        'DualStunHandlerSingleton: call initialize() before initializeDI().',
      );
    }

    late final SingletonHandlerFactory factory;
    try {
      factory = SingletonDIAccess.get<SingletonHandlerFactory>();
    } catch (_) {
      factory = const SingletonHandlerFactory();
      await factory.initializeDI();
    }

    await initializeDualHandlerDI();

    SingletonDI.registerFactory<DualStunHandlerSingleton>(() => this);
    SingletonDIAccess.add<DualStunHandlerSingleton>();
  }
}
