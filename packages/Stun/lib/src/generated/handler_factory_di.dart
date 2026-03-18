// AUTO-GENERATED - DO NOT CHANGE
// ignore_for_file: directives_ordering, library_prefixes, unnecessary_import, unused_import

import 'package:singleton_manager/singleton_manager.dart';
import '../implementations/singleton/handler_factory.dart';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';
import '../implementations/handlers/stun_handler.dart';

class HandlerFactoryDI extends HandlerFactory implements ISingletonStandardDI {

  HandlerFactoryDI() : super();

  factory HandlerFactoryDI.initializeDI() {
    final instance = HandlerFactoryDI();
    instance.initializeDI();
    return instance;
  }

  @override
  void initializeDI() {
  }
}
