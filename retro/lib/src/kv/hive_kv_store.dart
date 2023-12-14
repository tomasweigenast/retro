import 'package:hive/hive.dart';
import 'package:retro/retro.dart';

/// A [KvStore] backed by a [Hive] box.
///
/// You must supply a Box's name or a Box's instance.
/// The [Box] must be a dynamic box.
final class HiveKvStore implements KvStore {
  final Box _box;

  HiveKvStore({required String boxName}) : _box = Hive.box(boxName);
  HiveKvStore.box({required Box box}) : _box = box;

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  get(String key) => _box.get(key);

  @override
  Future<void> set(String key, value) => _box.put(key, value);
}
