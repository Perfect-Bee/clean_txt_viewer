import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../domain/txt_file_info.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.fileInfo,
    required this.pageIndex,
    required this.previewPageIndex,
    required this.loading,
    required this.selectable,
    required this.onSelectableChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onDecreaseFontSize,
    required this.onIncreaseFontSize,
  });

  final TxtFileInfo fileInfo;
  final int pageIndex;
  final int previewPageIndex;
  final bool loading;
  final bool selectable;

  final ValueChanged<bool> onSelectableChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;
  final VoidCallback onDecreaseFontSize;
  final VoidCallback onIncreaseFontSize;

  @override
  Widget build(BuildContext context) {
    final lastPage = math.max(0, fileInfo.pageCount - 1);
    final sliderMax = lastPage == 0 ? 1.0 : lastPage.toDouble();
    final sliderValue = previewPageIndex.clamp(0, lastPage).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fileInfo.name} · ${FileSizeFormatter.format(fileInfo.length)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '페이지 ${pageIndex + 1} / ${fileInfo.pageCount}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: '이전 페이지',
                onPressed: loading ? null : onPreviousPage,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: sliderMax,
                  divisions: lastPage > 0 && lastPage <= 500 ? lastPage : null,
                  onChanged: lastPage == 0 || loading
                      ? null
                      : onSliderChanged,
                  onChangeEnd: lastPage == 0 || loading
                      ? null
                      : onSliderChangeEnd,
                ),
              ),
              IconButton(
                tooltip: '다음 페이지',
                onPressed: loading ? null : onNextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              const Text('텍스트 선택'),
              Switch(
                value: selectable,
                onChanged: onSelectableChanged,
              ),
              const Spacer(),
              IconButton(
                tooltip: '글자 작게',
                onPressed: onDecreaseFontSize,
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                tooltip: '글자 크게',
                onPressed: onIncreaseFontSize,
                icon: const Icon(Icons.text_increase),
              ),
            ],
          ),
        ],
      ),
    );
  }
}