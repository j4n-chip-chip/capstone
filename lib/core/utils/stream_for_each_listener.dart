import 'dart:async';

/// Keeps a stable stream identity while creating a source for every listener.
///
/// Firebase streams can be single-subscription. Each listen must call the
/// Firebase getter again so concurrent screens and remounted widgets receive
/// their own initial snapshot and release their own subscription on cancel.
Stream<T> streamForEachListener<T>(Stream<T> Function() createStream) {
  return Stream<T>.multi((controller) {
    try {
      final subscription = createStream().listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = subscription.cancel;
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      controller.close();
    }
  }, isBroadcast: true);
}
