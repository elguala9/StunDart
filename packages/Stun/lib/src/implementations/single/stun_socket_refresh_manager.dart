import 'package:callback_handler/callback_handler.dart';
import '../../types/stun_types.dart';

/// Manages socket refresh callbacks for StunHandler
///
/// This class handles the registration and execution of callbacks that fire
/// when a socket is recreated due to network errors. It adapts user callbacks
/// (which take 2 individual parameters) to the CallbackHandler's tuple format.
class StunSocketRefreshManager {
  /// Internal callback handler that uses tuple format for performance
  /// Uses (newResponse, oldResponse) tuple instead of individual parameters
  final CallbackHandler<(StunResponse, StunResponse?), void> handler =
      CallbackHandler();

  /// Maps user callbacks to their wrapper functions
  ///
  /// Why this exists: Users provide callbacks with signature
  /// OnSocketRefresh = void Function(StunResponse, StunResponse?)
  /// but CallbackHandler expects void Function((StunResponse, StunResponse?))
  /// (note the extra parentheses - it's a tuple!)
  ///
  /// This map lets us:
  /// 1. Convert from the user's familiar format to CallbackHandler's tuple format
  /// 2. Store the wrapper so we can unregister the exact same function later
  /// 3. Use putIfAbsent() to prevent duplicate registrations
  final Map<OnSocketRefresh, void Function((StunResponse, StunResponse?))>
  _callbackWrapperMap = {};

  /// Register a socket refresh callback
  ///
  /// This method converts the user's callback to a wrapper function that
  /// the internal CallbackHandler can understand, then stores the mapping.
  /// Uses putIfAbsent() to prevent registering the same callback twice.
  void register(OnSocketRefresh callback) {
    _callbackWrapperMap.putIfAbsent(callback, () {
      // Create a wrapper that converts tuple (data.$1, data.$2)
      // to individual parameters for the user's callback
      void wrapper((StunResponse, StunResponse?) data) =>
          callback(data.$1, data.$2);
      handler.register(wrapper);
      return wrapper;
    });
  }

  /// Unregister a socket refresh callback
  ///
  /// Finds the wrapper function using the original callback as a key,
  /// then unregisters that specific wrapper from the internal handler.
  /// If the callback was never registered, does nothing.
  void unregister(OnSocketRefresh callback) {
    final wrapper = _callbackWrapperMap.remove(callback);
    if (wrapper != null) {
      handler.unregister(wrapper);
    }
  }

  /// Trigger all registered socket refresh callbacks
  ///
  /// Called when the socket is recreated. Passes the new result and
  /// the previous cached result to all registered callbacks.
  void fire(StunResponse newResponse, StunResponse? oldResponse) {
    handler.call((newResponse, oldResponse));
  }
}
