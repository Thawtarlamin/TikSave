import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class DownloadHistoryScreen extends StatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final Directory baseDir = await getApplicationDocumentsDirectory();

      final Directory downloadFolder = Directory(
        '${baseDir.path}/TikTokDownloads',
      );

      if (await downloadFolder.exists()) {
        final fileList = downloadFolder.listSync().where((file) {
          return file is File;
        }).toList();

        fileList.sort((a, b) {
          return b.statSync().modified.compareTo(a.statSync().modified);
        });

        if (!mounted) return;

        setState(() {
          _files = fileList;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _files = [];
        });
      }
    } catch (e) {
      debugPrint('Error reading folder: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openFile(String path) async {
    final result = await OpenFilex.open(path);

    if (result.type != ResultType.done && mounted) {
      _showMessage('Could not open this file.', error: true);
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final fileName = file.path.split('/').last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A20),
          title: const Text(
            'Delete file?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to delete "$fileName"?',
            style: const TextStyle(color: Colors.white60),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await file.delete();
      await _loadDownloadedFiles();

      if (mounted) {
        _showMessage('File deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not delete the file.', error: true);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFF2A151A)
              : const Color(0xFF12251E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                color: error
                    ? const Color(0xFFFF6B81)
                    : const Color(0xFF62E6A7),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloaded',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Your saved media',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadDownloadedFiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFE2C55)),
              )
            : _files.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: const Color(0xFFFE2C55),
                onRefresh: _loadDownloadedFiles,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    return _buildFileCard(_files[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFE2C55).withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 42,
                color: Color(0xFFFE2C55),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No downloads yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Downloaded videos and audio will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                // IndexedStack is controlled by parent.
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Start downloading'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    final isVideo = fileName.toLowerCase().endsWith('.mp4');
    final stat = file.statSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openFile(file.path),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: isVideo
                      ? const Color(0xFFFE2C55).withValues(alpha: 0.12)
                      : const Color(0xFF25F4EE).withValues(alpha: 0.10),
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                  color: isVideo
                      ? const Color(0xFFFE2C55)
                      : const Color(0xFF25F4EE),
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_formatFileSize(stat.size)}  •  ${_formatDate(stat.modified)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white54,
                ),
                color: const Color(0xFF202025),
                onSelected: (value) {
                  if (value == 'open') {
                    _openFile(file.path);
                  }

                  if (value == 'delete') {
                    _deleteFile(file);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 19),
                          SizedBox(width: 10),
                          Text('Open'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: Color(0xFFFF6B81),
                          ),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
