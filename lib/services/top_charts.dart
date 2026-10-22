import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/top_chart.dart';
export '../models/top_chart.dart';

const topChartsKey = 'vocalo1ng.topCharts.v1';
final topCharts = TopCharts();

class TopCharts extends ChangeNotifier {
  final charts = <TopChart>[];
  Future<void>? _loading;
  Future<void> _saving = Future.value();
  Timer? _timer;
  String? error;
  bool ready = false;
  bool _closed = false;
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        topChartsKey,
      );
      final loaded = raw == null ? [TopChart()] : decodeTopCharts(raw);
      charts
        ..clear()
        ..addAll(loaded);
      if (charts.isEmpty) charts.add(TopChart());
      ready = true;
      error = null;
    } catch (_) {
      error = '榜单读取失败，原数据已保留。请重试或导入备份。';
    }
    if (!_closed) notifyListeners();
  }

  Future<void> reload() async {
    _timer?.cancel();
    _timer = null;
    await _saving;
    _loading = null;
    ready = false;
    await load();
  }

  void changed() {
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      _timer = null;
      _persist();
    });
  }

  Future<void> _persist() {
    if (!ready) return Future.value();
    final snapshot = encodeTopCharts(charts);
    final task = _saving.then((_) async {
      try {
        decodeTopCharts(snapshot);
        if (!await (await SharedPreferences.getInstance()).setString(
          topChartsKey,
          snapshot,
        )) {
          throw StateError('write');
        }
        error = null;
      } catch (_) {
        error = '榜单未保存，请重试。自选封面过多时可先导出备份，再减少图片。';
      }
      if (!_closed) notifyListeners();
    });
    _saving = task;
    return task;
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await _persist();
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
