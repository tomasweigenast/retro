import 'package:retro/retro.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group("ZipRepository", () {
    test("insert", () async {
      final repository = ZipRepository<Tweet, String>(repositories: [
        newMemoryRepository(),
        newMemoryRepository(),
      ], options: kZipRepositoryTestOptions);

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
      ], options: kZipRepositoryTestOptions);

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
        ], options: kZipRepositoryTestOptions);

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
        ], options: kZipRepositoryTestOptions);

        final updated = await repository.update("a", Update.update((data) {
          data.content = "Hello world";
          data.tags.add("bikes");
          return data;
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
        ], options: kZipRepositoryTestOptions);

        expect(await repository.get("a"), isNotNull);
      });

      test("available in last", () async {
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(),
          newMemoryRepository([newTweet("a")]),
        ], options: kZipRepositoryTestOptions);

        expect(await repository.get("a"), isNotNull);
      });

      test("not found", () async {
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(),
          newMemoryRepository(),
        ], options: kZipRepositoryTestOptions);

        expect(await repository.get("a"), isNull);
      });

      test("one repository only", () async {
        final repository = ZipRepository<Tweet, String>(
            repositories: [
              newMemoryRepository([newTweet("a"), newTweet("b")]),
            ],
            options: ZipRepositoryOptions(
                refreshInterval: Duration.zero, readType: ReadType.firstIn));

        expect(await repository.get("a"), isNotNull);
      });

      test("one repository only list", () async {
        final repository = ZipRepository<Tweet, String>(
            repositories: [
              newMemoryRepository(manyTweets()),
            ],
            options: ZipRepositoryOptions(
                refreshInterval: Duration.zero, readType: ReadType.firstIn));

        expect(
            await repository
                .list(Query(
                    filters: [Filter.equals(field: "visible", value: false)],
                    pagination: OffsetPagination(pageSize: 20)))
                .then((value) => value.resultset),
            isNotEmpty);
      });
    });

    group("refresh", () {
      test("one repository", () async {
        final data = manyTweets();
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(data, true),
          newMemoryRepository(),
        ], options: ZipRepositoryOptions(kvStore: MemoryKvStore()));

        await repository.refresh();
        expect(
            (repository.repositories[1] as MemoryRepository).getCurrentData(),
            equals((repository.repositories[0] as MemoryRepository)
                .getCurrentData()));
      });

      test("two repositories", () async {
        final data = manyTweets();
        final repository = ZipRepository<Tweet, String>(repositories: [
          newMemoryRepository(data, true),
          newMemoryRepository(),
          newMemoryRepository(),
        ], options: ZipRepositoryOptions(kvStore: MemoryKvStore()));

        await repository.refresh();
        expect(
            (repository.repositories[1] as MemoryRepository).getCurrentData(),
            equals((repository.repositories[0] as MemoryRepository)
                .getCurrentData()));

        expect(
            (repository.repositories[2] as MemoryRepository).getCurrentData(),
            equals((repository.repositories[0] as MemoryRepository)
                .getCurrentData()));
      });
    });
  });

  group("DynamicIdZipRepository", () {
    test("insert", () async {
      final repository = DynamicIdZipRepository<Tweet, String>(repositories: [
        IdTransformer(
            transform: (id) => int.parse(id),
            repository: newIntMemoryRepository()),
        IdTransformer.noTransform(repository: newMemoryRepository()),
      ], options: kZipRepositoryTestOptions);

      final data = newTweet("1");
      await repository.insert(data);

      final remote = repository.repositories[0] as MemoryRepository;
      final local = repository.repositories[1] as MemoryRepository;

      expect(remote.getCurrentData()[1], equals(data));
      expect(local.getCurrentData()["1"], equals(data));
    });

    test("get", () async {
      final tweet = newTweet("1");
      final repository = DynamicIdZipRepository<Tweet, String>(repositories: [
        IdTransformer(
            transform: (id) => int.parse(id),
            repository: newIntMemoryRepository([tweet])),
        IdTransformer.noTransform(repository: newMemoryRepository()),
      ], options: kZipRepositoryTestOptions);

      expect(await repository.get("1"), equals(tweet));
    });

    test("delete", () async {
      final repository = DynamicIdZipRepository<Tweet, String>(repositories: [
        IdTransformer(
            transform: (id) => int.parse(id),
            repository: newIntMemoryRepository([newTweet("1")])),
        IdTransformer.noTransform(repository: newMemoryRepository()),
      ], options: kZipRepositoryTestOptions);

      await repository.delete("1");

      final remote = repository.repositories[0] as MemoryRepository;
      final local = repository.repositories[1] as MemoryRepository;

      expect(remote.getCurrentData()[1], isNull);
      expect(local.getCurrentData()["1"], isNull);
    });

    group("update", () {
      test("update.write", () async {
        final data = newTweet("1");
        final repository = DynamicIdZipRepository<Tweet, String>(repositories: [
          IdTransformer(
              transform: (id) => int.parse(id),
              repository: newIntMemoryRepository([data])),
          IdTransformer.noTransform(repository: newMemoryRepository([data])),
        ], options: kZipRepositoryTestOptions);

        final newData = newTweet("1");
        await repository.update("1", Update.write(newData));

        final remote = repository.repositories[0] as MemoryRepository;
        final local = repository.repositories[1] as MemoryRepository;

        expect(remote.getCurrentData()[1], equals(newData));
        expect(local.getCurrentData()["1"], equals(newData));
      });

      test("update.updater", () async {
        final data = newTweet("1");
        final repository = DynamicIdZipRepository<Tweet, String>(repositories: [
          IdTransformer(
              transform: (id) => int.parse(id),
              repository: newIntMemoryRepository([data])),
          IdTransformer.noTransform(repository: newMemoryRepository([data])),
        ], options: kZipRepositoryTestOptions);

        final updated = await repository.update("1", Update.update((data) {
          data.content = "Hello world";
          data.tags.add("bikes");
          return data;
        }));

        final remote = repository.repositories[0] as MemoryRepository;
        final local = repository.repositories[1] as MemoryRepository;

        expect(remote.getCurrentData()[1], equals(updated));
        expect(local.getCurrentData()["1"], equals(updated));
      });
    });
  });
}
