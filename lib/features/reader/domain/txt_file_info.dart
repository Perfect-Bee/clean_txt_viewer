class TxtFileInfo {
  const TxtFileInfo({
    required this.path,
    required this.name,
    required this.length,
    required this.pageCount,
  });

  final String path;
  final String name;
  final int length;
  final int pageCount;
}