import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../domain/txt_file_info.dart';
import '../domain/txt_reader_config.dart';

class TxtFilePicker {
  Future<TxtFileInfo?> pickTxtFile() async {
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

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final path = result.files.single.path!;
    final file = File(path);
    final length = await file.length();

    final pageCount =
        (length + TxtReaderConfig.pageSizeBytes - 1) ~/
        TxtReaderConfig.pageSizeBytes;

    return TxtFileInfo(
      path: path,
      name: _basename(path),
      length: length,
      pageCount: pageCount == 0 ? 1 : pageCount,
    );
  }

  String _basename(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}