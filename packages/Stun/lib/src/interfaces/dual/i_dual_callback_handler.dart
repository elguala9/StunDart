import 'dart:io';

import '../../types/stun_types.dart';

abstract interface class IDualCallbackHandler {
  OnSocketRefresh getOn({InternetAddressType type = InternetAddressType.IPv6});
  void register(void Function((StunResponse, StunResponse?)) wrapper, {InternetAddressType type = InternetAddressType.IPv6});
  void clear({InternetAddressType type = InternetAddressType.IPv6});
}
