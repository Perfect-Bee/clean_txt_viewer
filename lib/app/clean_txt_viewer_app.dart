import 'package:flutter/material.dart';

import '../features/reader/presentation/txt_reader_screen.dart';
import 'app_theme.dart';

class CleanTxtViewerApp extends StatelessWidget {
  const CleanTxtViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean TXT Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const TxtReaderScreen(),
    );
  }
}