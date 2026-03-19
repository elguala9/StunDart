// AUTO-GENERATED - DO NOT CHANGE
// ignore_for_file: directives_ordering, library_prefixes, unnecessary_import, unused_import

import 'package:singleton_manager/singleton_manager.dart';
import '../implementations/singleton/stun_handler_base.dart';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:stun/src/interfaces/i_dual_callback_handler.dart';
import 'package:stun/stun.dart';
import '../types/stun_types.dart';
import '../interfaces/i_stun_handler.dart';
import '../implementations/handlers/dual_stun_handler.dart';
import '../implementations/singleton/dual_callback_handler.dart';
import '../implementations/singleton/singleton_handler_factory.dart';

class StunHandlerBaseDI extends StunHandlerBase
    implements ISingletonStandardDI {
  StunHandlerBaseDI() : super();

  factory StunHandlerBaseDI.initializeDI() {
    final instance = StunHandlerBaseDI();
    instance.initializeDI();
    return instance;
  }

  @override
  void initializeDI() {
    dualHandlerProtected = SingletonDIAccess.get<IDualStunHandler>();
    callbacks = SingletonDIAccess.get<IDualCallbackHandler>();
  }
}
