// AUTO-GENERATED - DO NOT CHANGE
// ignore_for_file: directives_ordering, library_prefixes, unnecessary_import, unused_import

import 'package:singleton_manager/singleton_manager.dart';
import '../implementations/dual/dual_stun_handler_base.dart';
import 'dart:io';
import 'package:meta/meta.dart';
import '../interfaces/dual/i_dual_callback_handler.dart';
import 'package:stun/stun.dart';
import '../types/stun_types.dart';
import '../interfaces/single/i_stun_handler.dart';
import '../implementations/dual/dual_stun_handler.dart';
import '../implementations/dual/dual_callback_handler.dart';
import '../implementations/dual/singleton_handler_factory.dart';

class DualStunHandlerBaseDI extends DualStunHandlerBase
    implements ISingletonStandardDI {
  DualStunHandlerBaseDI() : super();

  factory DualStunHandlerBaseDI.initializeDI() {
    final instance = DualStunHandlerBaseDI();
    instance.initializeDI();
    return instance;
  }

  @override
  void initializeDI() {
    dualHandlerProtected = SingletonDIAccess.get<IDualStunHandler>();
    callbacks = SingletonDIAccess.get<IDualCallbackHandler>();
  }
}
