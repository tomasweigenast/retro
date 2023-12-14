abstract interface class KvStore {
  dynamic get(String key);
  Future<void> set(String key, dynamic value);
  Future<void> delete(String key);
}
