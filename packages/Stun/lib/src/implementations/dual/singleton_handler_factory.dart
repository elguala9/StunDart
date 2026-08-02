import 'handler_factory.dart';
import 'package:singleton_manager/singleton_manager.dart';

@dependencyInjectable
/// Singleton-registered factory for creating STUN handler instances
class SingletonHandlerFactory extends HandlerFactory {
  const SingletonHandlerFactory();

  void destroy() {
    // No-op: factory doesn't manage resources that need cleanup
  }
}
