abstract interface class Hydratable<T> {
  Future<void> hydrate(List<T> data);
}
