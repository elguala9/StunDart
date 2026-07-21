import 'dart:io';

import 'package:meta/meta.dart';

import '../../implementations/single/stun_handler.dart';
import '../../interfaces/single/i_stun_handler.dart';
import '../../types/stun_types.dart';

/// Internal-only behavior of `HandlerFactory`: single creation path for both
/// IP families. Not part of the package's public API — do not export it from
/// `stun.dart`.
@internal
mixin HandlerFactoryMixin {
  /// Creates a handler without socket for the requested IP family
  Future<IStunHandler> createHandler({
    required InternetAddressType type,
    String? address,
    int? port,
    Duration timeout = const Duration(seconds: 5),
    OnSocketRefresh? onSocketRefresh,
  }) => StunHandler.withoutSocket(
    address: address,
    port: port,
    type: type,
    timeout: timeout,
    onSocketRefresh: onSocketRefresh,
  );
}
