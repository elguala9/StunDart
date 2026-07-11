import 'package:singleton_manager/singleton_manager.dart';

import 'i_stun_handler_base.dart';

abstract interface class IStunHandlerSingleton
    implements IStunHandlerBase, ISingletonStandardDI {
  /// Initialize dependency injection - registers singleton and handlers in DI container
  @override
  Future<void> initializeDI();
}
