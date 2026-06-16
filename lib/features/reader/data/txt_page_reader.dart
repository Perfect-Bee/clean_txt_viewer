import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/utf8_decoder.dart';
import '../domain/txt_file_info.dart';
import '../domain/txt_reader_config.dart';

class TxtPageReader {
  final LinkedHashMap<int, List<String>> _pageCache = LinkedHashMap();

  Future<List<String>> readPage({
    required TxtFileInfo fileInfo,
    required int pageIndex,
  }) async {
    final cached = _pageCache.remove(pageIndex);

    if (cached != null) {
      _pageCache[pageIndex] = cached;
      return cached;
    }

    final start = pageIndex * TxtReaderConfig.pageSizeBytes;

    if (start >= fileInfo.length) {
      return const [];
    }

    final desiredLength = math.min(
      TxtReaderConfig.pageSizeBytes,
      fileInfo.length - start,
    );

    final readLength = math.min(
      TxtReaderConfig.pageSizeBytes + 3,
      fileInfo.length - start,
    );

    final raf = await File(fileInfo.path).open(mode: FileMode.read);

    try {
      await raf.setPosition(start);
      final bytes = await raf.read(readLength);

      final text = await compute(decodeUtf8Safely, {
        'bytes': bytes,
        'desiredLength': desiredLength,
      });

      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      final lines = normalized.split('\n');

      _putCache(pageIndex, lines);

      return lines;
    } finally {
      await raf.close();
    }
  }

  void prefetchAround({
    required TxtFileInfo fileInfo,
    required int pageIndex,
  }) {
    for (final page in <int>[pageIndex + 1, pageIndex - 1]) {
      if (page < 0 || page >= fileInfo.pageCount) continue;
      if (_pageCache.containsKey(page)) continue;

      Future<void>(() async {
        try {
          await readPage(
            fileInfo: fileInfo,
            pageIndex: page,
          );
        } catch (_) {
          // 미리 읽기는 실패해도 현재 화면에 영향을 주지 않는다.
        }
      });
    }
  }

  void clearCache() {
    _pageCache.clear();
  }

  void _putCache(int index, List<String> lines) {
    _pageCache.remove(index);
    _pageCache[index] = lines;

    while (_pageCache.length > TxtReaderConfig.maxCachedPages) {
      _pageCache.remove(_pageCache.keys.first);
    }
  }
}