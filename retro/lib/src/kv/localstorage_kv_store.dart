import 'package:retro/retro.dart';
import 'package:universal_html/html.dart' as html;

/// A [KvStore] backed by [localStorage] in web.
final class LocalStorageKvStore implements KvStore {
  @override
  Future<void> delete(String key) {
    html.window.localStorage.remove(key);
    return Future.value();
  }

  @override
  dynamic get(String key) {
    return html.window.localStorage[key];
  }

  @override
  Future<void> set(String key, value) {
    html.window.localStorage[key] = value;
    return Future.value();
  }
}
