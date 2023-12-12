import 'package:retro/retro.dart';

import 'tweet.dart';

void main() {
  final memoryRepository = MemoryRepository<Tweet, String>(
      toJson: (tweet) => tweet.toJson(), fromJson: Tweet.fromJson, idGetter: (tweet) => tweet.id);

  memoryRepository.insert(Tweet(
      id: "123",
      content: "Hello world",
      createdAt: DateTime.now(),
      userId: "abc",
      userName: "John Doe",
      visible: true,
      tags: ["economy", "country"]));

  final tweet = memoryRepository.get("123");
  print(tweet);
}
