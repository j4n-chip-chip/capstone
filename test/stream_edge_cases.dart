// Standalone stream regressions: dart test/stream_edge_cases.dart
import 'dart:async';
import 'dart:io';

import '../lib/core/utils/stream_for_each_listener.dart';

int checked = 0;
int failed = 0;

void expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

Future<void> edge(String label, Future<void> Function() body) async {
  checked++;
  try {
    await body().timeout(const Duration(seconds: 2));
    stdout.writeln('PASS: $label');
  } catch (error, stackTrace) {
    failed++;
    stderr.writeln('FAIL: $label -- $error\n$stackTrace');
  }
}

// Like Firebase, every getter call supplies a single-subscription stream
// whose first event contains the current snapshot even without a new write.
class SnapshotSource {
  int current = 1;
  int cancelled = 0;
  final controllers = <StreamController<int>>[];

  Stream<int> open() {
    late StreamController<int> controller;
    controller = StreamController<int>(
      onListen: () => controller.add(current),
      onCancel: () => cancelled++,
    );
    controllers.add(controller);
    return controller.stream;
  }

  void update(int value) {
    current = value;
    for (final controller in controllers) {
      if (controller.hasListener) controller.add(value);
    }
  }
}

Future<void> main() async {
  await edge(
    'An unused cached stream defers Firebase source creation',
    () async {
      final source = SnapshotSource();
      streamForEachListener(source.open);
      expect(
        source.controllers.isEmpty,
        'Unused stream eagerly created a Firebase source.',
      );
    },
  );

  await edge(
    'Six simultaneous assignment listeners accept the same stream',
    () async {
      final source = SnapshotSource();
      final stream = streamForEachListener(source.open)
          .map((id) => 'device-$id');
      final snapshots = await Future.wait(
        List.generate(6, (_) => stream.first),
      );
      expect(
        snapshots.every((value) => value == 'device-1'),
        'A screen missed its initial assignment.',
      );
      expect(
        source.cancelled == 6,
        'Completed listeners left subscriptions open.',
      );
    },
  );

  await edge(
    'A cancelled stream can be listened to again after tab reopening',
    () async {
      final source = SnapshotSource();
      final stream = streamForEachListener(source.open);
      await stream.first;
      source.current = 9;
      expect(
        await stream.first == 9,
        'Reopened tab received a stale snapshot.',
      );
      expect(
        source.cancelled == 2,
        'Reopened tab did not release its subscription.',
      );
    },
  );

  await edge(
    'A connection first check completes while a screen is listening',
    () async {
      final source = SnapshotSource();
      final stream = streamForEachListener(source.open);
      final screenEvents = <int>[];
      final screen = stream.listen(screenEvents.add);
      try {
        await flushEvents();
        expect(
          await stream.first == 1,
          'Command check waited for a new database write.',
        );
        source.update(2);
        await flushEvents();
        expect(
          screenEvents.join(',') == '1,2',
          'Command check cancelled the screen subscription.',
        );
        expect(
          source.cancelled == 1,
          'One-shot check left its subscription open.',
        );
      } finally {
        await screen.cancel();
      }
    },
  );

  await edge('Cancelling one view does not cancel another view', () async {
    final source = SnapshotSource();
    final stream = streamForEachListener(source.open);
    final firstEvents = <int>[];
    final secondEvents = <int>[];
    final first = stream.listen(firstEvents.add);
    final second = stream.listen(secondEvents.add);
    try {
      await flushEvents();
      await first.cancel();
      source.update(3);
      await flushEvents();
      expect(
        firstEvents.join(',') == '1',
        'Cancelled view kept receiving events.',
      );
      expect(
        secondEvents.join(',') == '1,3',
        'Remaining view stopped receiving events.',
      );
      expect(
        source.cancelled == 1,
        'Cancellation affected the wrong number of sources.',
      );
    } finally {
      await first.cancel();
      await second.cancel();
    }
  });

  await edge(
    'Pausing one listener neither blocks nor loses another listener update',
    () async {
      final source = SnapshotSource();
      final stream = streamForEachListener(source.open);
      final pausedEvents = <int>[];
      final activeEvents = <int>[];
      final paused = stream.listen(pausedEvents.add);
      final active = stream.listen(activeEvents.add);
      try {
        await flushEvents();
        paused.pause();
        source.update(4);
        await flushEvents();
        expect(
          pausedEvents.join(',') == '1',
          'Paused listener received an event early.',
        );
        expect(
          activeEvents.join(',') == '1,4',
          'Paused listener blocked another view.',
        );
        paused.resume();
        await flushEvents();
        expect(
          pausedEvents.join(',') == '1,4',
          'Paused listener lost its buffered update.',
        );
      } finally {
        await paused.cancel();
        await active.cancel();
      }
    },
  );

  await edge(
    'Firebase errors retain their stack trace and do not terminate other views',
    () async {
      final source = SnapshotSource();
      final stream = streamForEachListener(source.open);
      final errors = <Object>[];
      StackTrace? receivedStack;
      final secondEvents = <int>[];
      final first = stream.listen(
        (_) {},
        onError: (Object error, StackTrace stack) {
          errors.add(error);
          receivedStack = stack;
        },
      );
      final second = stream.listen(secondEvents.add);
      try {
        await flushEvents();
        final denied = StateError('permission-denied');
        final stack = StackTrace.fromString('firebase-test-stack');
        source.controllers.first.addError(denied, stack);
        source.update(5);
        await flushEvents();
        expect(
          errors.length == 1 && identical(errors.single, denied),
          'Firebase error was lost or changed.',
        );
        expect(
          receivedStack.toString() == stack.toString(),
          'Firebase stack trace was lost.',
        );
        expect(
          secondEvents.join(',') == '1,5',
          'A source error broke another view.',
        );
      } finally {
        await first.cancel();
        await second.cancel();
      }
    },
  );

  await edge(
    'A completed source can be reopened without reusing a consumed stream',
    () async {
      var opened = 0;
      final stream = streamForEachListener(() => Stream.value(++opened));
      expect(
        (await stream.toList()).single == 1,
        'First source did not complete.',
      );
      expect(
        (await stream.toList()).single == 2,
        'Completed source was reused.',
      );
    },
  );

  await edge(
    'A source factory failure is delivered as a recoverable stream error',
    () async {
      var unavailable = true;
      final denied = StateError('Firebase unavailable');
      final stream = streamForEachListener<int>(() {
        if (unavailable) throw denied;
        return Stream.value(7);
      });
      final errors = <Object>[];
      await stream.handleError(errors.add).toList();
      expect(
        errors.length == 1 && identical(errors.single, denied),
        'Factory failure escaped the stream error handler.',
      );
      unavailable = false;
      expect(
        await stream.first == 7,
        'A failed factory permanently broke the cached stream.',
      );
    },
  );

  await edge(
    'Refreshing the cache does not orphan existing listeners',
    () async {
      final source = SnapshotSource();
      final cache = <String, Stream<int>>{};
      Stream<int> cached() =>
          cache.putIfAbsent('device', () => streamForEachListener(source.open));
      final oldStream = cached();
      expect(
        identical(cached(), oldStream),
        'Rebuild changed the cached stream identity.',
      );
      final oldEvents = <int>[];
      final old = oldStream.listen(oldEvents.add);
      try {
        await flushEvents();
        cache.clear();
        final refreshed = cached();
        expect(
          !identical(refreshed, oldStream),
          'Refresh reused the old cache entry.',
        );
        expect(
          await refreshed.first == 1,
          'Refreshed stream missed its initial snapshot.',
        );
        source.update(6);
        await flushEvents();
        expect(
          oldEvents.join(',') == '1,6',
          'Refresh orphaned a mounted listener.',
        );
      } finally {
        await old.cancel();
      }
      expect(
        source.cancelled == source.controllers.length,
        'Refresh leaked a source subscription.',
      );
    },
  );

  stdout.writeln('RESULT: $checked stream edge cases, $failed failures.');
  exitCode = failed == 0 ? 0 : 1;
}
