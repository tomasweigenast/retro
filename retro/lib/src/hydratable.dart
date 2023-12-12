abstract interface class Hydratable<T, Id> {
  Future<void> hydrate(Map<Id, T> data);
}
