import 'package:collection/collection.dart';

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

  Map<String, dynamic> toJson() => {
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
