import 'package:callback_handler/callback_handler.dart';
import '../../types/stun_types.dart';

/// Manages socket refresh callbacks for StunHandler
class StunSocketRefreshManager {
  final CallbackHandler<(StunResponse, StunResponse?), void> handler =
      CallbackHandler();

  final Map<OnSocketRefresh, void Function((StunResponse, StunResponse?))>
      _callbackWrapperMap = {};

  /// Register a socket refresh callback
  void register(OnSocketRefresh callback) {
    _callbackWrapperMap.putIfAbsent(callback, () {
      void wrapper((StunResponse, StunResponse?) data) =>
          callback(data.$1, data.$2);
      handler.register(wrapper);
      return wrapper;
    });
  }

  /// Unregister a socket refresh callback
  void unregister(OnSocketRefresh callback) {
    final wrapper = _callbackWrapperMap.remove(callback);
    if (wrapper != null) {
      handler.unregister(wrapper);
    }
  }

  /// Fire the socket refresh callback
  void fire(StunResponse newResponse, StunResponse? oldResponse) {
    handler.call((newResponse, oldResponse));
  }
}
