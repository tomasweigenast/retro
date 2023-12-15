import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:retro/retro.dart';

final class Tweet {
  final String id;
  final DateTime createdAt;
  final String userName;
  final String userId;
  final List<String> tags;
  String content;
  bool visible;

  Tweet(
      {required this.id,
      required this.content,
      required this.createdAt,
      required this.userId,
      required this.userName,
      required this.visible,
      required this.tags});

  @override
  String toString() =>
      "Id [$id] Content [$content] UserId [$userId] UserName [$userName] CreatedAt [$createdAt] Visible [$visible] Tags [$tags]";

  factory Tweet.fromJson(Map json) => Tweet(
      id: json["id"],
      content: json["content"],
      visible: json["visible"],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json["createdAt"]),
      userId: json["userId"],
      userName: json["userName"],
      tags: (json["tags"] as Iterable).cast<String>().toList());

  static Map<String, dynamic> toJson(Tweet tweet) => tweet._toJson();

  Map<String, dynamic> _toJson() => {
        "id": id,
        "content": content,
        "createdAt": createdAt.millisecondsSinceEpoch,
        "userId": userId,
        "visible": visible,
        "userName": userName,
        "tags": tags
      };

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => other is Tweet
      ? other.id == id &&
          other.content == content &&
          other.userId == userId &&
          other.userName == userName &&
          other.createdAt == createdAt &&
          other.visible == visible &&
          const DeepCollectionEquality.unordered().equals(other.tags, tags)
      : false;
}

final _faker = Faker(seed: 123456789);
const _tags = ["economy", "business", "food", "race", "cars"];
Tweet newTweet([String? id]) => Tweet(
        id: id ?? _faker.guid.guid(),
        content: _faker.lorem.sentence(),
        userId: _faker.guid.guid(),
        createdAt: _truncate(_faker.date.dateTime(minYear: 2023, maxYear: 2024)),
        visible: _faker.randomGenerator.boolean(),
        userName: _faker.person.name(),
        tags: [
          _tags[_faker.randomGenerator.integer(_tags.length)],
          _tags[_faker.randomGenerator.integer(_tags.length)],
        ]);

List<Tweet> manyTweets([int size = 100]) => List.generate(100, (i) => newTweet(i.toString()));

MemoryRepository<Tweet, String> newMemoryRepository(
    [List<Tweet>? initialData, bool remote = false]) {
  if (remote) {
    return RemoteMemoryRepository(
        idGetter: (tweet) => tweet.id,
        toJson: Tweet.toJson,
        fromJson: Tweet.fromJson,
        initialData: initialData == null
            ? null
            : Map.fromEntries(initialData.map((e) => MapEntry(e.id, e))));
  } else {
    return MemoryRepository(
        idGetter: (tweet) => tweet.id,
        toJson: Tweet.toJson,
        fromJson: Tweet.fromJson,
        initialData: initialData == null
            ? null
            : Map.fromEntries(initialData.map((e) => MapEntry(e.id, e))));
  }
}

MemoryRepository<Tweet, int> newIntMemoryRepository(
    [List<Tweet>? initialData, bool remote = false]) {
  if (remote) {
    return RemoteMemoryRepository(
        idGetter: (tweet) => int.parse(tweet.id),
        toJson: Tweet.toJson,
        fromJson: Tweet.fromJson,
        initialData: initialData == null
            ? null
            : Map.fromEntries(initialData.map((e) => MapEntry(int.parse(e.id), e))));
  } else {
    return MemoryRepository(
        idGetter: (tweet) => int.parse(tweet.id),
        toJson: Tweet.toJson,
        fromJson: Tweet.fromJson,
        initialData: initialData == null
            ? null
            : Map.fromEntries(initialData.map((e) => MapEntry(int.parse(e.id), e))));
  }
}

DateTime _truncate(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);

class RemoteMemoryRepository<T, Id> extends MemoryRepository<T, Id> implements DataProvider<T> {
  RemoteMemoryRepository(
      {required super.toJson,
      required super.fromJson,
      required super.idGetter,
      super.equalityComparers,
      super.initialData,
      super.name,
      super.queryTranslator});

  @override
  Future<Batch<T>> poll({DateTime? from, String? continuationToken}) async {
    final data = getCurrentData();
    return Batch(data: data.values.toList(growable: false));
  }
}

const kZipRepositoryTestOptions = ZipRepositoryOptions(
  refreshInterval: Duration.zero,
);

final class MemoryKvStore implements KvStore {
  final Map<String, dynamic> _cache = {};

  @override
  Future<void> delete(String key) {
    _cache.remove(key);
    return Future.value();
  }

  @override
  get(String key) => _cache[key];

  @override
  Future<void> set(String key, value) {
    _cache[key] = value;
    return Future.value();
  }
}
