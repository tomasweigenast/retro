final class Update<T> {
  final T? _data;
  final void Function(T data)? _updater;

  T? get data => _data;
  void Function(T data)? get updater => _updater;

  Update.write(T data)
      : _data = data,
        _updater = null;

  Update.update(void Function(T data) updater)
      : _updater = updater,
        _data = null;
}
