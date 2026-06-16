import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

String decodeUtf8Safely(Map<String, Object> message) {
  final bytes = message['bytes'] as Uint8List;
  final desiredLength = message['desiredLength'] as int;

  if (bytes.isEmpty) return '';

  var start = 0;

  while (
      start < bytes.length &&
      start < desiredLength &&
      isUtf8Continuation(bytes[start])) {
    start++;
  }

  var end = math.min(desiredLength, bytes.length);

  while (end < bytes.length && isUtf8Continuation(bytes[end])) {
    end++;
  }

  if (end < start) {
    end = start;
  }

  final safeBytes = bytes.sublist(start, end);

  return const Utf8Decoder(
    allowMalformed: true,
  ).convert(safeBytes);
}

bool isUtf8Continuation(int byte) {
  return (byte & 0xC0) == 0x80;
}