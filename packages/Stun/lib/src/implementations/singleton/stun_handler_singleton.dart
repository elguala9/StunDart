import 'package:singleton_manager/singleton_manager.dart';

import '../../interfaces/i_stun_handler_singleton.dart';
import 'stun_handler_base.dart';
import 'singleton_handler_factory.dart';

/// Singleton wrapper for managing dual IPv4 and IPv6 STUN handlers
class StunHandlerSingleton extends StunHandlerBase
    implements IStunHandlerSingleton {
  factory StunHandlerSingleton() => _instance;
  StunHandlerSingleton._internal() : super();

  static final StunHandlerSingleton _instance =
      StunHandlerSingleton._internal();
  static StunHandlerSingleton get instance => _instance;

  @override
  Future<void> initializeDI() async {
    if (dualHandler.getHandler(ipv6: false) == null) {
      throw StateError(
        'StunHandlerSingleton: call initialize() before initializeDI().',
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

    SingletonDI.registerFactory<StunHandlerSingleton>(() => this);
    SingletonDIAccess.add<StunHandlerSingleton>();
  }
}
