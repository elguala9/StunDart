import 'package:singleton_manager/singleton_manager.dart';

import '../../mixins/dual/handler_factory_mixin.dart';

/// Base factory for creating STUN handler instances
@isSingleton
class HandlerFactory with HandlerFactoryMixin {
  const HandlerFactory();
}
