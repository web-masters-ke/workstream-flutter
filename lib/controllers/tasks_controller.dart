import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/task.dart';
import '../services/tasks_service.dart';

enum TaskSort { deadline, rate, newest }

class TaskFilter {
  final TaskCategory? category;
  final double minRate;
  final bool remoteOnly;
  const TaskFilter({this.category, this.minRate = 0, this.remoteOnly = false});

  TaskFilter copyWith({
    TaskCategory? category,
    double? minRate,
    bool? remoteOnly,
    bool clearCategory = false,
  }) =>
      TaskFilter(
        category: clearCategory ? null : (category ?? this.category),
        minRate: minRate ?? this.minRate,
        remoteOnly: remoteOnly ?? this.remoteOnly,
      );
}

class TasksController extends ChangeNotifier {
  final _svc = TasksService();

  List<Task> _available = [];
  List<Task> _assigned = [];
  List<Task> _inProgress = [];
  List<Task> _completed = [];

  bool _loading = false;
  String? _error;

  TaskFilter _filter = const TaskFilter();
  TaskSort _sort = TaskSort.deadline;

  List<Task> get available => _apply(_available);
  List<Task> get assigned => _assigned;
  List<Task> get inProgress => _inProgress;
  List<Task> get completed => _completed;
  bool get loading => _loading;
  String? get error => _error;
  TaskFilter get filter => _filter;
  TaskSort get sort => _sort;

  void setFilter(TaskFilter f) {
    _filter = f;
    notifyListeners();
  }

  void setSort(TaskSort s) {
    _sort = s;
    notifyListeners();
  }

  List<Task> get upcomingDeadline {
    final all = [..._assigned, ..._inProgress]
      ..sort((a, b) {
        final ad = a.deadline?.millisecondsSinceEpoch ?? 1 << 62;
        final bd = b.deadline?.millisecondsSinceEpoch ?? 1 << 62;
        return ad.compareTo(bd);
      });
    return all.take(3).toList();
  }

  List<Task> _apply(List<Task> list) {
    var out = [...list];
    if (_filter.category != null) {
      out = out.where((t) => t.category == _filter.category).toList();
    }
    if (_filter.minRate > 0) {
      out = out.where((t) => t.reward >= _filter.minRate).toList();
    }
    switch (_sort) {
      case TaskSort.deadline:
        out.sort((a, b) {
          final ad = a.deadline?.millisecondsSinceEpoch ?? 1 << 62;
          final bd = b.deadline?.millisecondsSinceEpoch ?? 1 << 62;
          return ad.compareTo(bd);
        });
        break;
      case TaskSort.rate:
        out.sort((a, b) => b.reward.compareTo(a.reward));
        break;
      case TaskSort.newest:
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return out;
  }

  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.cachedTasks);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      List<Task> parse(String k) => ((j[k] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _available = parse('available');
      _assigned = parse('assigned');
      _inProgress = parse('inProgress');
      _completed = parse('completed');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.cachedTasks,
      jsonEncode({
        'available': _available.map((e) => e.toJson()).toList(),
        'assigned': _assigned.map((e) => e.toJson()).toList(),
        'inProgress': _inProgress.map((e) => e.toJson()).toList(),
        'completed': _completed.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _available = await _svc.available();
      final mine = await _svc.mine();
      _assigned = mine.where((t) => t.status == TaskStatus.assigned).toList();
      _inProgress =
          mine.where((t) => t.status == TaskStatus.inProgress).toList();
      _completed = mine
          .where(
            (t) =>
                t.status == TaskStatus.completed ||
                t.status == TaskStatus.submitted,
          )
          .toList();
      await _persist();
    } catch (e) {
      _error = e.toString();
      _available = [];
      _assigned = [];
      _inProgress = [];
      _completed = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Task? byId(String id) {
    for (final list in [_available, _assigned, _inProgress, _completed]) {
      for (final t in list) {
        if (t.id == id) return t;
      }
    }
    return null;
  }

  Future<bool> accept(String id) async {
    try {
      await _svc.accept(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reject(String id, {String? reason}) async {
    try {
      await _svc.reject(id, reason: reason);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> start(String id) async {
    try {
      await _svc.start(id);
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submit(
    String id, {
    String? notes,
    String? outcome,
    String? attachmentUrl,
  }) async {
    try {
      await _svc.submit(
        id,
        notes: notes,
        outcome: outcome,
        attachmentUrl: attachmentUrl,
      );
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reload() => loadAll();
}
