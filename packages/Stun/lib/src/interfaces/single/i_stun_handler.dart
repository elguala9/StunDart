import 'dart:io';

import '../single/i_stun_handler_base.dart';

/// Interface for STUN handler
abstract class IStunHandler implements IStunHandlerBase {
  InternetAddressType getIpVersion();
}
