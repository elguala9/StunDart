import 'package:singleton_manager/singleton_manager.dart';

import '../i_stun_handler_base.dart';

abstract interface class IDualStunHandlerSingleton
    implements IStunHandlerBase, ISingletonStandardDI {
  @override
  Future<void> initializeDI();
}
