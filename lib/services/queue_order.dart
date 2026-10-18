import 'dart:math';

enum PlayMode {
  sequential('顺序播放'),
  loop('列表循环'),
  single('单曲循环'),
  shuffle('随机播放');

  const PlayMode(this.label);
  final String label;
}

class QueueOrder {
  QueueOrder({Random? random}) : random = random ?? Random();
  final Random random;
  PlayMode mode = PlayMode.sequential;
  final List<int> history = [];
  final List<int> remaining = [];

  void reset() {
    history.clear();
    remaining.clear();
  }

  int? next(int current, int length, {bool completed = false}) {
    if (current < 0 || length == 0) return null;
    if (completed && mode == PlayMode.single) return current;
    if (mode == PlayMode.shuffle) {
      if (length == 1) return completed ? current : null;
      if (remaining.isEmpty) {
        remaining.addAll(List.generate(length, (i) => i)..remove(current));
        remaining.shuffle(random);
      }
      history.add(current);
      return remaining.removeLast();
    }
    if (current + 1 < length) return current + 1;
    return mode == PlayMode.loop || mode == PlayMode.single ? 0 : null;
  }

  int? previous(int current, int length) {
    if (mode == PlayMode.shuffle) {
      return history.isEmpty ? null : history.removeLast();
    }
    if (current > 0) return current - 1;
    return length > 0 && mode != PlayMode.sequential ? length - 1 : null;
  }
}
