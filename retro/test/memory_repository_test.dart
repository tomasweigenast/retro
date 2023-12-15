import 'package:collection/collection.dart';
import 'package:retro/retro.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group("MemoryRepository", () {
    test("insert and get", () {
      final repo = newMemoryRepository();
      final t = newTweet();
      repo.insert(t);

      expect(repo.get(t.id), equals(t));
      expect(repo.get("a"), isNull);
    });

    test("delete", () {
      final repo = newMemoryRepository([newTweet("a")]);
      expect(repo.get("a"), isNotNull);
      repo.delete("a");
      expect(repo.get("a"), isNull);
    });

    group("update", () {
      test("callback", () {
        final tweet = newTweet("a");
        final repo = newMemoryRepository([tweet]);
        final before = repo.get("a");
        expect(before, equals(tweet));

        final after = repo.update("a", Update.update((data) {
          data.content = "Hello world";
          data.visible = !data.visible;
          return data;
        }));
        expect(after, isNot(equals(tweet)));
        expect(repo.get("a"), isNot(equals(tweet)));
        expect(repo.get("a")?.content, "Hello world");
      });

      test("write", () {
        final tweet = newTweet("a");
        final repo = newMemoryRepository([tweet]);
        final before = repo.get("a");
        expect(before, equals(tweet));

        final after = repo.update(
            "a",
            Update.write(Tweet(
                id: tweet.id,
                userId: tweet.userId,
                userName: tweet.userName,
                createdAt: tweet.createdAt,
                content: "Hello world",
                visible: false,
                tags: [...tweet.tags, "new"])));

        expect(after, isNot(equals(tweet)));
        expect(repo.get("a"), isNot(equals(tweet)));
        expect(repo.get("a")?.content, "Hello world");
      });
    });

    group("list", () {
      test("single sort property", () {
        final data = manyTweets();
        final repo = newMemoryRepository(data);
        final result = repo.list(Query(
            sortBy: [Sort.descending("createdAt")],
            pagination: OffsetPagination(page: 0, pageSize: 100)));
        expect(result.length, equals(100));
        expect(result.nextPage, isNull);
        expect(result.nextPageToken, isNull);
        expect(result.resultset, equals(data..sort((a, b) => b.createdAt.compareTo(a.createdAt))));
      });

      test("two sort properties", () {
        final data = manyTweets();
        final repo = newMemoryRepository(data);
        final result = repo.list(Query(
            sortBy: [Sort.ascending("userName"), Sort.descending("createdAt")],
            pagination: OffsetPagination(page: 0, pageSize: 100)));
        expect(result.length, equals(100));
        expect(result.nextPage, isNull);
        expect(result.nextPageToken, isNull);
        expect(
            result.resultset,
            equals(data
              ..sort((a, b) {
                final result = a.userName.compareTo(b.userName);
                if (result != 0) {
                  return result;
                }

                return b.createdAt.compareTo(a.createdAt);
              })));
      });

      group("filter", () {
        final data = manyTweets();
        final repo = newMemoryRepository(data);
        final defaultPagination = OffsetPagination(page: 0, pageSize: 100);

        for (final testcase in <({
          String name,
          PagedResult<Tweet> Function(MemoryRepository<Tweet, String>) getter,
          List<Tweet> Function(List<Tweet>) expect
        })>[
          (
            name: 'equals',
            getter: (repo) => repo.list(Query(
                filters: [Filter.equals(field: 'visible', value: true)],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) => data.where((element) => element.visible).toList()
          ),
          (
            name: 'notEquals',
            getter: (repo) => repo.list(Query(
                filters: [Filter.notEquals(field: 'visible', value: true)],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) => data.where((element) => !element.visible).toList()
          ),
          (
            name: 'greaterThan',
            getter: (repo) => repo.list(Query(
                filters: [Filter.greaterThan(field: 'createdAt', value: DateTime(2022, 5))],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) =>
                data.where((element) => element.createdAt.isAfter(DateTime(2022, 5))).toList()
          ),
          (
            name: 'greaterThanOrEquals',
            getter: (repo) => repo.list(Query(
                filters: [Filter.greaterThanOrEquals(field: 'createdAt', value: DateTime(2022, 5))],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) =>
                    element.createdAt.isAtSameMomentAs(DateTime(2022, 5)) ||
                    element.createdAt.isAfter(DateTime(2022, 5)))
                .toList()
          ),
          (
            name: 'lessThan',
            getter: (repo) => repo.list(Query(
                filters: [Filter.lessThan(field: 'createdAt', value: DateTime(2022, 5))],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) =>
                data.where((element) => element.createdAt.isBefore(DateTime(2022, 5))).toList()
          ),
          (
            name: 'lessThanOrEquals',
            getter: (repo) => repo.list(Query(
                filters: [Filter.lessThanOrEquals(field: 'createdAt', value: DateTime(2022, 5))],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) =>
                    element.createdAt.isAtSameMomentAs(DateTime(2022, 5)) ||
                    element.createdAt.isBefore(DateTime(2022, 5)))
                .toList()
          ),
          (
            name: 'between',
            getter: (repo) => repo.list(Query(filters: [
                  Filter.between(field: 'createdAt', values: [DateTime(2023, 5), DateTime(2024)])
                ], pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) =>
                    element.createdAt.millisecondsSinceEpoch >=
                        DateTime(2023, 5).millisecondsSinceEpoch &&
                    element.createdAt.millisecondsSinceEpoch <=
                        DateTime(2024).millisecondsSinceEpoch)
                .toList()
          ),
          (
            name: 'inArray',
            getter: (repo) => repo.list(Query(filters: [
                  Filter.inArray(field: 'userId', values: [
                    "69dd9483-dcad-b261-d96c-bd6d35ca1738",
                    "a2322cc2-f629-3f23-2469-c0e220bfff30"
                  ])
                ], pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) => [
                      "69dd9483-dcad-b261-d96c-bd6d35ca1738",
                      "a2322cc2-f629-3f23-2469-c0e220bfff30"
                    ].contains(element.userName))
                .toList()
          ),
          (
            name: 'notInArray',
            getter: (repo) => repo.list(Query(filters: [
                  Filter.notInArray(field: 'userId', values: [
                    "69dd9483-dcad-b261-d96c-bd6d35ca1738",
                    "a2322cc2-f629-3f23-2469-c0e220bfff30"
                  ])
                ], pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) => ![
                      "69dd9483-dcad-b261-d96c-bd6d35ca1738",
                      "a2322cc2-f629-3f23-2469-c0e220bfff30"
                    ].contains(element.userName))
                .toList()
          ),
          (
            name: 'contains(array)',
            getter: (repo) => repo.list(Query(
                filters: [Filter.contains(field: 'tags', value: "food")],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) =>
                data.where((element) => element.tags.contains("food")).toList()
          ),
          (
            name: 'contains(string)',
            getter: (repo) => repo.list(Query(
                filters: [Filter.contains(field: 'content', value: "Ipsum")],
                pagination: defaultPagination)),
            expect: (List<Tweet> data) =>
                data.where((element) => element.content.contains("Ipsum")).toList()
          ),
          (
            name: 'containsAny',
            getter: (repo) => repo.list(Query(filters: [
                  Filter.containsAny(field: 'tags', values: ["Ipsum", "Sit", "sit", "ipsum"])
                ], pagination: defaultPagination)),
            expect: (List<Tweet> data) => data
                .where((element) =>
                    ["Ipsum", "Sit", "sit", "ipsum"].any((tag) => element.content.contains(tag)))
                .toList()
          ),
        ]) {
          test(testcase.name, () {
            testcase.getter(repo);
          });
        }
      });

      group("pagination", () {
        final data = manyTweets();
        final repo = newMemoryRepository(data);

        test("without filters", () {
          var result = repo.list(Query(
              sortBy: [Sort.ascending("userName")], pagination: CursorPagination(pageSize: 50)));
          expect(result.length, equals(50));
          expect(result.nextPageToken, isNotNull);
          expect(result.resultset,
              equals(data.sorted((a, b) => a.userName.compareTo(b.userName)).take(50).toList()));

          result = repo.list(Query(
              sortBy: [Sort.ascending("userName")],
              pagination: CursorPagination(pageToken: result.nextPageToken, pageSize: 50)));
          expect(result.length, equals(50));
          expect(result.nextPageToken, isNull);
          expect(
              result.resultset,
              equals(data
                  .sorted((a, b) => a.userName.compareTo(b.userName))
                  .skip(50)
                  .take(50)
                  .toList()));
        });

        test("with filters", () {
          var result = repo.list(Query(
              filters: [Filter.equals(field: 'visible', value: true)],
              sortBy: [Sort.ascending("userName")],
              pagination: CursorPagination(pageSize: 5)));
          expect(result.length, equals(5));
          expect(result.nextPageToken, isNotNull);
          expect(
              result.resultset,
              equals(data
                  .sorted((a, b) => a.userName.compareTo(b.userName))
                  .where((element) => element.visible)
                  .take(5)
                  .toList()));

          result = repo.list(Query(
              filters: [Filter.equals(field: 'visible', value: true)],
              sortBy: [Sort.ascending("userName")],
              pagination: CursorPagination(pageToken: result.nextPageToken, pageSize: 5)));
          expect(result.length, equals(5));
          expect(
              result.resultset,
              equals(data
                  .sorted((a, b) => a.userName.compareTo(b.userName))
                  .where((element) => element.visible)
                  .skip(5)
                  .take(5)
                  .toList()));
        });
      });
    });
  });
}
