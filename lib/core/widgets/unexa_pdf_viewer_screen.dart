import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// In-app PDF viewer. Downloads the file to a temp location and shows it
/// full-screen inside UNEXA — no external browser needed.
class UnexaPdfViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const UnexaPdfViewerScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<UnexaPdfViewerScreen> createState() => _UnexaPdfViewerScreenState();
}

class _UnexaPdfViewerScreenState extends State<UnexaPdfViewerScreen> {
  String? _localPath;
  String? _error;
  double _progress = 0;
  bool _downloading = true;
  int _pages = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  Future<void> _downloadFile() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'unexa_${widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${widget.url.hashCode}.pdf';
      final savePath = '${dir.path}/$fileName';

      final file = File(savePath);
      if (await file.exists()) {
        setState(() {
          _localPath = savePath;
          _downloading = false;
        });
        return;
      }

      await Dio().download(
        widget.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (mounted) {
        setState(() {
          _localPath = savePath;
          _downloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load the PDF. Check your connection.';
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_pages > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '$_currentPage / $_pages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_downloading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    strokeWidth: 4,
                  ),
                ),
                Text(
                  _progress > 0 ? '${(_progress * 100).toInt()}%' : '',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Loading ${widget.title}…',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _downloading = true;
                    _error = null;
                    _progress = 0;
                  });
                  _downloadFile();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: Text('File not available.'));
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      onRender: (pages) => setState(() => _pages = pages ?? 0),
      onPageChanged: (page, total) {
        if (page != null) setState(() => _currentPage = page + 1);
      },
      onError: (error) => setState(() {
        _error = 'Could not display the PDF.';
        _downloading = false;
      }),
    );
  }
}
