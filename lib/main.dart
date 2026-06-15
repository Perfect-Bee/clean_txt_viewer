import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FastTxtReaderApp());
}

class FastTxtReaderApp extends StatelessWidget {
  const FastTxtReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast TXT Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const TxtReaderScreen(),
    );
  }
}

class TxtReaderScreen extends StatefulWidget {
  const TxtReaderScreen({super.key});

  @override
  State<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends State<TxtReaderScreen> {
  static const int _pageSizeBytes = 64 * 1024;
  static const int _maxCachedPages = 9;

  final LinkedHashMap<int, List<String>> _pageCache = LinkedHashMap();

  String? _filePath;
  String _fileName = '';
  int _fileLength = 0;
  int _pageCount = 1;
  int _pageIndex = 0;
  int _previewPageIndex = 0;

  List<String> _lines = const [];
  bool _loading = false;
  bool _selectable = false;
  double _fontSize = 15;

  String? _error;
  int _fileVersion = 0;
  int _loadTicket = 0;

  Future<void> _pickAndOpen() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'log',
          'md',
          'csv',
          'json',
          'xml',
        ],
      );

      if (!mounted) return;

      if (result == null || result.files.single.path == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);
      final length = await file.length();

      _fileVersion++;
      _pageCache.clear();

      final pageCount = (length + _pageSizeBytes - 1) ~/ _pageSizeBytes;

      setState(() {
        _filePath = path;
        _fileName = _basename(path);
        _fileLength = length;
        _pageCount = pageCount == 0 ? 1 : pageCount;
        _pageIndex = 0;
        _previewPageIndex = 0;
        _lines = const [];
      });

      await _showPage(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '파일을 열 수 없습니다.\n$e';
      });
    }
  }

  Future<void> _showPage(int index) async {
    if (_filePath == null) return;

    final clamped = _clampPage(index);
    final version = _fileVersion;
    final ticket = ++_loadTicket;

    setState(() {
      _loading = true;
      _error = null;
      _previewPageIndex = clamped;
    });

    try {
      final lines = await _readPageLines(clamped, version);

      if (!mounted || ticket != _loadTicket || version != _fileVersion) {
        return;
      }

      setState(() {
        _pageIndex = clamped;
        _previewPageIndex = clamped;
        _lines = lines;
        _loading = false;
      });

      _prefetchAround(clamped, version);
    } catch (e) {
      if (!mounted || ticket != _loadTicket) return;

      setState(() {
        _loading = false;
        _error = '페이지를 읽을 수 없습니다.\n$e';
      });
    }
  }

  Future<List<String>> _readPageLines(int index, int version) async {
    if (version != _fileVersion) return const [];

    final cached = _pageCache.remove(index);
    if (cached != null) {
      _pageCache[index] = cached;
      return cached;
    }

    final path = _filePath;
    if (path == null) return const [];

    final start = index * _pageSizeBytes;
    if (start >= _fileLength) return const [];

    final desiredLength = math.min(_pageSizeBytes, _fileLength - start);
    final readLength = math.min(_pageSizeBytes + 3, _fileLength - start);

    final raf = await File(path).open(mode: FileMode.read);

    try {
      await raf.setPosition(start);
      final bytes = await raf.read(readLength);

      final text = await compute(_decodeUtf8Safely, {
        'bytes': bytes,
        'desiredLength': desiredLength,
      });

      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final lines = normalized.split('\n');

      if (version == _fileVersion) {
        _putCache(index, lines);
      }

      return lines;
    } finally {
      await raf.close();
    }
  }

  void _putCache(int index, List<String> lines) {
    _pageCache.remove(index);
    _pageCache[index] = lines;

    while (_pageCache.length > _maxCachedPages) {
      _pageCache.remove(_pageCache.keys.first);
    }
  }

  void _prefetchAround(int index, int version) {
    for (final page in <int>[index + 1, index - 1]) {
      if (page < 0 || page >= _pageCount) continue;
      if (_pageCache.containsKey(page)) continue;

      unawaited(
        _readPageLines(page, version).catchError(
          (_) => const <String>[],
        ),
      );
    }
  }

  int _clampPage(int index) {
    if (index < 0) return 0;
    if (index >= _pageCount) return _pageCount - 1;
    return index;
  }

  String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;

    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }

    final fixed = size < 10 && unit > 0 ? 1 : 0;
    return '${size.toStringAsFixed(fixed)} ${units[unit]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast TXT Reader'),
        actions: [
          IconButton(
            tooltip: '파일 열기',
            onPressed: _pickAndOpen,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: _filePath == null ? _buildEmptyView() : _buildReaderView(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: FilledButton.icon(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('TXT 파일 열기'),
      ),
    );
  }

  Widget _buildReaderView() {
    return Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(child: _buildTextView()),
      ],
    );
  }

  Widget _buildToolbar() {
    final lastPage = math.max(0, _pageCount - 1);
    final sliderMax = lastPage == 0 ? 1.0 : lastPage.toDouble();
    final sliderValue = _previewPageIndex.clamp(0, lastPage).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_fileName · ${_formatBytes(_fileLength)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '페이지 ${_pageIndex + 1} / $_pageCount',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: '이전 페이지',
                onPressed: _loading || _pageIndex <= 0
                    ? null
                    : () => _showPage(_pageIndex - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: sliderMax,
                  divisions: lastPage > 0 && lastPage <= 500 ? lastPage : null,
                  onChanged: lastPage == 0 || _loading
                      ? null
                      : (value) {
                          setState(() {
                            _previewPageIndex = value.round();
                          });
                        },
                  onChangeEnd: lastPage == 0 || _loading
                      ? null
                      : (value) {
                          _showPage(value.round());
                        },
                ),
              ),
              IconButton(
                tooltip: '다음 페이지',
                onPressed: _loading || _pageIndex >= _pageCount - 1
                    ? null
                    : () => _showPage(_pageIndex + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              const Text('텍스트 선택'),
              Switch(
                value: _selectable,
                onChanged: (value) {
                  setState(() {
                    _selectable = value;
                  });
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: '글자 작게',
                onPressed: () {
                  setState(() {
                    _fontSize = math.max(10, _fontSize - 1);
                  });
                },
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                tooltip: '글자 크게',
                onPressed: () {
                  setState(() {
                    _fontSize = math.min(30, _fontSize + 1);
                  });
                },
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextView() {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: 1.35,
    );

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Stack(
      children: [
        Scrollbar(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index].isEmpty ? ' ' : _lines[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: _selectable
                    ? SelectableText(
                        line,
                        style: style,
                      )
                    : Text(
                        line,
                        style: style,
                        softWrap: true,
                      ),
              );
            },
          ),
        ),
        if (_loading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

String _decodeUtf8Safely(Map<String, Object> message) {
  final bytes = message['bytes'] as Uint8List;
  final desiredLength = message['desiredLength'] as int;

  if (bytes.isEmpty) return '';

  var start = 0;

  while (
      start < bytes.length && start < desiredLength && _isUtf8Continuation(bytes[start])) {
    start++;
  }

  var end = math.min(desiredLength, bytes.length);

  while (end < bytes.length && _isUtf8Continuation(bytes[end])) {
    end++;
  }

  if (end < start) {
    end = start;
  }

  final safeBytes = bytes.sublist(start, end);
  return const Utf8Decoder(allowMalformed: true).convert(safeBytes);
}

bool _isUtf8Continuation(int byte) {
  return (byte & 0xC0) == 0x80;
}