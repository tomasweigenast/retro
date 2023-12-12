import 'dart:convert';

Map<String, dynamic> decodePageToken(String? pageToken) {
  if (pageToken == null || pageToken.isEmpty) {
    return const {};
  }

  try {
    return jsonDecode(utf8.decode(base64.decode(pageToken)));
  } catch (_) {
    return const {};
  }
}

String encodePageToken(Map<String, dynamic> data) {
  return base64.encode(utf8.encode(jsonEncode(data)));
}
