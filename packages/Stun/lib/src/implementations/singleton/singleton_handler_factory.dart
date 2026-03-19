import 'package:singleton_manager/singleton_manager.dart';

import 'handler_factory.dart';

/// Singleton-registered factory for creating STUN handler instances
class SingletonHandlerFactory extends HandlerFactory
    implements ISingletonStandardDI {
  const SingletonHandlerFactory();

  @override
  Future<void> initializeDI() async {
    SingletonDI.registerFactory<SingletonHandlerFactory>(() => this);
    SingletonDIAccess.add<SingletonHandlerFactory>();
  }

  void destroy() {
    // No-op: factory doesn't manage resources that need cleanup
  }
}
