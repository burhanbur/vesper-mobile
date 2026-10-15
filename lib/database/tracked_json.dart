import 'dart:collection';

typedef DirtyUnit = (String, String, String?);

/// Undo only changed fields. Financial commits must not copy a complete history
/// just to restore one failed row/outbox edit.
class JsonJournal {
  final List<void Function()> _undo = [];
  final Set<DirtyUnit> dirty = {};
  bool _replaying = false;

  void record(DirtyUnit unit, void Function() undo) {
    if (_replaying) return;
    dirty.add(unit);
    _undo.add(undo);
  }

  void committed() {
    _undo.clear();
    dirty.clear();
  }

  void rollback() {
    _replaying = true;
    try {
      for (final undo in _undo.reversed) {
        undo();
      }
    } finally {
      _replaying = false;
      committed();
    }
  }

  dynamic wrap(dynamic value, DirtyUnit unit) {
    if (value is TrackedMap &&
        identical(value.journal, this) &&
        value.unit == unit) {
      return value;
    }
    if (value is TrackedList &&
        identical(value.journal, this) &&
        value.unit == unit) {
      return value;
    }
    if (value is Map) {
      return TrackedMap(this, unit, Map<String, dynamic>.from(value));
    }
    if (value is List) return TrackedList(this, unit, value);
    return value;
  }
}

class TrackedMap extends MapBase<String, dynamic> {
  final JsonJournal journal;
  final DirtyUnit unit;
  final Map<String, dynamic> _values = {};
  TrackedMap(this.journal, this.unit, Map<String, dynamic> values) {
    for (final entry in values.entries) {
      _values[entry.key] = journal.wrap(entry.value, unit);
    }
  }

  @override
  dynamic operator [](Object? key) => _values[key];
  @override
  Iterable<String> get keys => _values.keys;
  @override
  bool containsKey(Object? key) => _values.containsKey(key);
  @override
  dynamic putIfAbsent(String key, dynamic Function() ifAbsent) {
    if (!containsKey(key)) this[key] = ifAbsent();
    return this[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    final wrapped = journal.wrap(value, unit);
    final existed = _values.containsKey(key), previous = _values[key];
    journal.record(unit, () {
      if (existed) {
        _values[key] = previous;
      } else {
        _values.remove(key);
      }
    });
    _values[key] = wrapped;
  }

  @override
  dynamic remove(Object? key) {
    if (key is! String || !_values.containsKey(key)) return null;
    final previous = _values[key];
    journal.record(unit, () => _values[key] = previous);
    return _values.remove(key);
  }

  @override
  void clear() {
    for (final key in keys.toList()) {
      remove(key);
    }
  }
}

class TrackedList extends ListBase<dynamic> {
  final JsonJournal journal;
  final DirtyUnit unit;
  final List<dynamic> _values;
  TrackedList(this.journal, this.unit, List<dynamic> values)
    : _values = values.map((value) => journal.wrap(value, unit)).toList();
  @override
  int get length => _values.length;
  @override
  set length(int value) {
    RangeError.checkNotNegative(value, 'length');
    final previous = List<dynamic>.of(_values);
    journal.record(unit, () {
      _values
        ..clear()
        ..addAll(previous);
    });
    _values.length = value;
  }

  @override
  dynamic operator [](int index) => _values[index];
  @override
  void operator []=(int index, dynamic value) {
    final previous = _values[index];
    journal.record(unit, () => _values[index] = previous);
    _values[index] = journal.wrap(value, unit);
  }

  @override
  void add(dynamic element) {
    final wrapped = journal.wrap(element, unit);
    journal.record(unit, () => _values.removeLast());
    _values.add(wrapped);
  }

  @override
  void insert(int index, dynamic element) {
    RangeError.checkValueInInterval(index, 0, _values.length, 'index');
    final wrapped = journal.wrap(element, unit);
    journal.record(unit, () => _values.removeAt(index));
    _values.insert(index, wrapped);
  }

  @override
  dynamic removeAt(int index) {
    final previous = _values[index];
    journal.record(unit, () => _values.insert(index, previous));
    return _values.removeAt(index);
  }
}
