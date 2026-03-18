// AUTO-GENERATED - DO NOT CHANGE
// ignore_for_file: directives_ordering, library_prefixes, unnecessary_import, unused_import

import 'package:singleton_manager/singleton_manager.dart';
import '../implementations/singleton/stun_handler_base.dart';
import 'dart:io';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';
import '../implementations/singleton/dual_callback_handler.dart';
import '../implementations/singleton/singleton_handler_factory.dart';
import '../implementations/singleton/stun_handler_operations.dart';

class StunHandlerBaseDI extends StunHandlerBase implements ISingletonStandardDI {

  StunHandlerBaseDI() : super();

  factory StunHandlerBaseDI.initializeDI() {
    final instance = StunHandlerBaseDI();
    instance.initializeDI();
    return instance;
  }

  @override
  void initializeDI() {
    callbacks = SingletonDIAccess.get<DualCallbackHandler>();
  }
}
