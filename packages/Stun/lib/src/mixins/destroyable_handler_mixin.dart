import 'package:meta/meta.dart';

/// Internal-only shared destroy-delegates-to-close behavior.
///
/// The mixing class provides [close] (possibly with additional optional
/// parameters); the mixin provides [destroy] as required by
/// `IValueForRegistry`. Not part of the package's public API — do not export
/// it from `stun.dart`.
@internal
mixin DestroyableHandlerMixin {
  /// Closes the underlying resources; provided by the mixing class.
  void close();

  /// Destroys the handler by closing it.
  void destroy() => close();
}
