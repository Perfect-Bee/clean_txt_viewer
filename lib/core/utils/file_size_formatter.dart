class FileSizeFormatter {
  const FileSizeFormatter._();

  static String format(int bytes) {
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
}