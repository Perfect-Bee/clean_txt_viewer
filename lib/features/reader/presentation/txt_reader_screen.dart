import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/txt_file_picker.dart';
import '../data/txt_page_reader.dart';
import '../domain/txt_file_info.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/text_line_list.dart';

class TxtReaderScreen extends StatefulWidget {
  const TxtReaderScreen({super.key});

  @override
  State<TxtReaderScreen> createState() => _TxtReaderScreenState();
}

class _TxtReaderScreenState extends State<TxtReaderScreen> {
  final TxtFilePicker _filePicker = TxtFilePicker();
  final TxtPageReader _pageReader = TxtPageReader();
  final ScrollController _scrollController = ScrollController();

  TxtFileInfo? _fileInfo;

  int _pageIndex = 0;
  int _previewPageIndex = 0;

  List<String> _lines = const [];

  bool _loading = false;
  bool _loadingMore = false;
  bool _selectable = false;
  double _fontSize = 15;

  String? _error;

  int _fileVersion = 0;
  int _loadTicket = 0;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;

      if (position.pixels >= position.maxScrollExtent - 800) {
        _loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndOpen() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fileInfo = await _filePicker.pickTxtFile();

      if (!mounted) return;

      if (fileInfo == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      _fileVersion++;
      _pageReader.clearCache();

      setState(() {
        _fileInfo = fileInfo;
        _pageIndex = 0;
        _previewPageIndex = 0;
        _lines = const [];
      });

      await _showPage(0, resetScroll: true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = '파일을 열 수 없습니다.\n$e';
      });
    }
  }

  Future<void> _showPage(
    int index, {
    bool resetScroll = false,
  }) async {
    final fileInfo = _fileInfo;
    if (fileInfo == null) return;

    final clamped = _clampPage(index);
    final version = _fileVersion;
    final ticket = ++_loadTicket;

    setState(() {
      _loading = true;
      _error = null;
      _previewPageIndex = clamped;
    });

    try {
      final lines = await _pageReader.readPage(
        fileInfo: fileInfo,
        pageIndex: clamped,
      );

      if (!mounted || ticket != _loadTicket || version != _fileVersion) {
        return;
      }

      setState(() {
        _pageIndex = clamped;
        _previewPageIndex = clamped;
        _lines = lines;
        _loading = false;
      });

      if (resetScroll && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      _pageReader.prefetchAround(
        fileInfo: fileInfo,
        pageIndex: clamped,
      );
    } catch (e) {
      if (!mounted || ticket != _loadTicket) return;

      setState(() {
        _loading = false;
        _error = '페이지를 읽을 수 없습니다.\n$e';
      });
    }
  }

  Future<void> _loadNextPage() async {
    final fileInfo = _fileInfo;

    if (fileInfo == null) return;
    if (_loading) return;
    if (_loadingMore) return;
    if (_pageIndex >= fileInfo.pageCount - 1) return;

    _loadingMore = true;

    try {
      final nextPage = _pageIndex + 1;
      final version = _fileVersion;

      final newLines = await _pageReader.readPage(
        fileInfo: fileInfo,
        pageIndex: nextPage,
      );

      if (!mounted || version != _fileVersion) return;

      setState(() {
        _pageIndex = nextPage;
        _previewPageIndex = nextPage;
        _lines = [
          ..._lines,
          ...newLines,
        ];
      });

      _pageReader.prefetchAround(
        fileInfo: fileInfo,
        pageIndex: nextPage,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '다음 페이지를 읽을 수 없습니다.\n$e';
      });
    } finally {
      _loadingMore = false;
    }
  }

  int _clampPage(int index) {
    final fileInfo = _fileInfo;

    if (fileInfo == null) return 0;
    if (index < 0) return 0;
    if (index >= fileInfo.pageCount) return fileInfo.pageCount - 1;

    return index;
  }

  @override
  Widget build(BuildContext context) {
    final fileInfo = _fileInfo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clean TXT Viewer'),
        actions: [
          IconButton(
            tooltip: '파일 열기',
            onPressed: _pickAndOpen,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: fileInfo == null ? _buildEmptyView() : _buildReaderView(fileInfo),
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

  Widget _buildReaderView(TxtFileInfo fileInfo) {
    return Column(
      children: [
        ReaderToolbar(
          fileInfo: fileInfo,
          pageIndex: _pageIndex,
          previewPageIndex: _previewPageIndex,
          loading: _loading,
          selectable: _selectable,
          onSelectableChanged: (value) {
            setState(() {
              _selectable = value;
            });
          },
          onPreviousPage: _pageIndex <= 0
              ? null
              : () => _showPage(_pageIndex - 1, resetScroll: true),
          onNextPage: _pageIndex >= fileInfo.pageCount - 1
              ? null
              : () => _showPage(_pageIndex + 1, resetScroll: true),
          onSliderChanged: (value) {
            setState(() {
              _previewPageIndex = value.round();
            });
          },
          onSliderChangeEnd: (value) {
            _showPage(value.round(), resetScroll: true);
          },
          onDecreaseFontSize: () {
            setState(() {
              _fontSize = math.max(10, _fontSize - 1);
            });
          },
          onIncreaseFontSize: () {
            setState(() {
              _fontSize = math.min(30, _fontSize + 1);
            });
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildTextView(),
        ),
      ],
    );
  }

  Widget _buildTextView() {
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
        TextLineList(
          lines: _lines,
          fontSize: _fontSize,
          selectable: _selectable,
          scrollController: _scrollController,
        ),
        if (_loading || _loadingMore)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}