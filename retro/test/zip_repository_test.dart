import 'package:retro/retro.dart';
import 'package:test/test.dart';

void main() {
  group("ZipRepository", () {
    test("insert", () async {
      final repository =
          ZipRepository<int, String>(repositories: [MemoryRepository(), MemoryRepository()]);

      await repository.insert("a", 123456789);

      final remote = repository.repositories[0] as MemoryRepository;
      final local = repository.repositories[1] as MemoryRepository;

      expect(remote.getCurrentData()["a"], equals(123456789));
      expect(local.getCurrentData()["a"], equals(123456789));
    });

    test("delete", () async {
      final repository = ZipRepository<int, String>(repositories: [
        MemoryRepository(initialData: {"a": 123}),
        MemoryRepository(initialData: {"a": 123})
      ]);

      await repository.delete("a");

      final remote = repository.repositories[0] as MemoryRepository<int, String>;
      final local = repository.repositories[1] as MemoryRepository<int, String>;

      expect(remote.getCurrentData()["a"], isNull);
      expect(local.getCurrentData()["a"], isNull);
    });

    group("update", () {
      test("update.write", () async {
        final repository = ZipRepository<Map<String, dynamic>, String>(repositories: [
          MemoryRepository(initialData: {
            "a": {"name": "Hola", "age": 12}
          }),
          MemoryRepository(initialData: {
            "a": {"name": "Hola", "age": 12}
          })
        ]);

        await repository.update("a", Update.write({"id": "a"}));

        final remote = repository.repositories[0] as MemoryRepository<Map<String, dynamic>, String>;
        final local = repository.repositories[1] as MemoryRepository<Map<String, dynamic>, String>;

        expect(remote.getCurrentData()["a"], equals({"id": "a"}));
        expect(local.getCurrentData()["a"], equals({"id": "a"}));
      });

      test("update.updater", () async {
        final repository = ZipRepository<Map<String, dynamic>, String>(repositories: [
          MemoryRepository(initialData: {
            "a": {"name": "Hola", "age": 12}
          }),
          MemoryRepository(initialData: {
            "a": {"name": "Hola", "age": 12}
          })
        ]);

        await repository.update("a", Update.update((data) {
          data["name"] = "Tomás";
          data["id"] = "a";
        }));

        final remote = repository.repositories[0] as MemoryRepository<Map<String, dynamic>, String>;
        final local = repository.repositories[1] as MemoryRepository<Map<String, dynamic>, String>;

        expect(remote.getCurrentData()["a"], equals({"name": "Tomás", "age": 12, "id": "a"}));
        expect(local.getCurrentData()["a"], equals({"name": "Tomás", "age": 12, "id": "a"}));
      });
    });

    group("get", () {
      test("available in first", () async {
        final repository = ZipRepository<int, String>(repositories: [
          MemoryRepository(initialData: {"a": 123}),
          MemoryRepository()
        ]);

        expect(await repository.get("a"), equals(123));
      });

      test("available in last", () async {
        final repository = ZipRepository<int, String>(repositories: [
          MemoryRepository(),
          MemoryRepository(initialData: {"a": 123})
        ]);

        expect(await repository.get("a"), equals(123));
      });

      test("not found", () async {
        final repository =
            ZipRepository<int, String>(repositories: [MemoryRepository(), MemoryRepository()]);

        expect(await repository.get("a"), isNull);
      });
    });
  });
}
