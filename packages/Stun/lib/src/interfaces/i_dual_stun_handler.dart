import 'package:singleton_manager/singleton_manager.dart';

import 'i_dual_handler_facade.dart';

/// Interface for managing dual IPv4 and IPv6 STUN handlers
/// Handles parallel request execution and state management
abstract class IDualStunHandler
    implements IDualHandlerFacade, ISingletonStandardDI {
  /// Initialize dependency injection - registers handlers in DI container
  @override
  Future<void> initializeDI();
}
