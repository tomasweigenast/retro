import 'package:retro/retro.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group("ZipRepository", () {
    test("insert", () async {
      final repository = ZipRepository<Tweet, String>(repositories: [
        newMemoryRepository(),
        newMemoryRepository(),
      ]);

      final data = newTweet("a");
      await repository.insert(data);

      final remote = repository.repositories[0] as MemoryRepository;
      final local = repository.repositories[1] as MemoryRepository;

      expect(remote.getCurrentData()["a"], equals(data));
      expect(local.getCurrentData()["a"], equals(data));
    });

    test("delete", () async {
      final repository = ZipRepository<Tweet, String>(repositories: [
        newMemoryRepository([newTweet("a")]),
        newMemoryRepository(),
      ]);

      await repository.delete("a");

      final remote = repository.repositories[0] as MemoryRepository;
      final local = repository.repositories[1] as MemoryRepository;

      expect(remote.getCurrentData()["a"], isNull);
      expect(local.getCurrentData()["a"], isNull);
    });

    group("update", () {
      test("update.write", () async {
        final data = newTweet("a");
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository([data]),
          newMemoryRepository([data]),
        ]);

        final newData = newTweet("a");
        await repository.update("a", Update.write(newData));

        final remote = repository.repositories[0] as MemoryRepository;
        final local = repository.repositories[1] as MemoryRepository;

        expect(remote.getCurrentData()["a"], equals(newData));
        expect(local.getCurrentData()["a"], equals(newData));
      });

      test("update.updater", () async {
        final data = newTweet("a");
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository([data]),
          newMemoryRepository([data]),
        ]);

        final updated = await repository.update("a", Update.update((data) {
          data.content = "Hello world";
          data.tags.add("bikes");
        }));

        final remote = repository.repositories[0] as MemoryRepository;
        final local = repository.repositories[1] as MemoryRepository;

        expect(remote.getCurrentData()["a"], equals(updated));
        expect(local.getCurrentData()["a"], equals(updated));
      });
    });

    group("get", () {
      test("available in first", () async {
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository([newTweet("a")]),
          newMemoryRepository(),
        ]);

        expect(await repository.get("a"), isNotNull);
      });

      test("available in last", () async {
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(),
          newMemoryRepository([newTweet("a")]),
        ]);

        expect(await repository.get("a"), isNotNull);
      });

      test("not found", () async {
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(),
          newMemoryRepository(),
        ]);

        expect(await repository.get("a"), isNull);
      });
    });
  });
}
