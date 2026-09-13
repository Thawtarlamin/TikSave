import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();

  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.66:8000',
  );

  final Map<String, String> _headers = {
    'Accept': '*/*',
    'User-Agent': 'TikSave',
    'Content-Type': 'application/json',
  };

  String? cleanTikTokUrl(String input) {
    final regExp = RegExp(
      r'^(https?:\/\/(?:www\.)?tiktok\.com\/@[\w.-]+\/video\/\d+)',
    );

    final match = regExp.firstMatch(input);
    return match?.group(1);
  }

  bool _isLoadingInfo = false;
  bool _isPreparingDownload = false;

  double _downloadProgress = 0.0;
  String _downloadingType = '';

  Map<String, dynamic>? _videoInfo;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchInfo() async {
    final inputUrl = _urlController.text.trim();

    if (inputUrl.isEmpty) {
      _showError('Please paste a TikTok video URL.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingInfo = true;
      _videoInfo = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/info'),
        headers: _headers,
        body: jsonEncode({'url': cleanTikTokUrl(inputUrl) ?? inputUrl}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          _videoInfo = Map<String, dynamic>.from(data);
        });
      } else {
        _showError('Could not get video information.');
      }
    } catch (e) {
      _showError('Connection failed. Please check your server.');
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingInfo = false;
      });
    }
  }

  Future<void> _processVideoDownload() async {
    final inputUrl = _urlController.text.trim();

    if (inputUrl.isEmpty) {
      _showError('Please paste a TikTok video URL.');
      return;
    }

    setState(() {
      _isPreparingDownload = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/v1/download'),
        headers: _headers,
        body: jsonEncode({'url': cleanTikTokUrl(inputUrl) ?? inputUrl}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final downloadData = jsonDecode(response.body);

        if (downloadData['ok'] == true) {
          final String fileUrl = downloadData['download_url'];
          final String fileName =
              downloadData['filename'] ?? 'video_${downloadData['id']}.mp4';

          await _saveFile(fileUrl, fileName, 'video');
        } else {
          _showError('Download link is not available.');
        }
      } else {
        _showError('Could not create download link.');
      }
    } catch (e) {
      _showError('Video download failed.');
    } finally {
      if (!mounted) return;

      setState(() {
        _isPreparingDownload = false;
      });
    }
  }

  Future<void> _processAudioDownload() async {
    final musicUrl = _videoInfo?['music_url'];

    if (musicUrl == null || musicUrl.toString().isEmpty) {
      _showError('Audio URL is not available.');
      return;
    }

    final fileName =
        'tiktok_audio_${_videoInfo?['id'] ?? DateTime.now().millisecondsSinceEpoch}.mp3';

    await _saveFile(musicUrl.toString(), fileName, 'audio');
  }

  Future<void> _saveFile(String fileUrl, String fileName, String type) async {
    setState(() {
      _downloadProgress = 0.001;
      _downloadingType = type;
    });

    try {
      final Directory baseDir = await getApplicationDocumentsDirectory();

      final Directory downloadFolder = Directory(
        '${baseDir.path}/TikTokDownloads',
      );

      if (!await downloadFolder.exists()) {
        await downloadFolder.create(recursive: true);
      }

      final savePath = '${downloadFolder.path}/$fileName';

      await Dio().download(
        fileUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (!mounted) return;

      _showSuccess(
        '${type == 'video' ? 'Video' : 'Audio'} saved successfully.',
      );
    } catch (e) {
      if (mounted) {
        _showError('Download failed. Please try again.');
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _downloadProgress = 0.0;
        _downloadingType = '';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A151A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFFF6B81)),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF12251E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF62E6A7)),
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
              'TikSave',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Save videos & audio',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: () {
              _urlController.clear();

              setState(() {
                _videoInfo = null;
              });
            },
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(),
              const SizedBox(height: 24),
              _buildUrlInput(),
              const SizedBox(height: 12),
              _buildFetchButton(),
              if (_downloadProgress > 0) ...[
                const SizedBox(height: 18),
                _buildDownloadProgress(),
              ],
              if (_videoInfo != null) ...[
                const SizedBox(height: 24),
                _buildVideoPreview(),
              ],
              const SizedBox(height: 24),
              _buildTipCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241118), Color(0xFF15151A)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFE2C55), Color(0xFFFF5275)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFE2C55).withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.download_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download anything',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'Paste a TikTok link and get your media in seconds.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video URL',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Paste TikTok video URL...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(
              Icons.link_rounded,
              color: Color(0xFF25F4EE),
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _urlController,
              builder: (context, value, child) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                return IconButton(
                  onPressed: () {
                    _urlController.clear();

                    setState(() {
                      _videoInfo = null;
                    });
                  },
                  icon: const Icon(Icons.clear_rounded, size: 20),
                );
              },
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFetchButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: _isLoadingInfo ? null : _fetchInfo,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFE2C55),
          disabledBackgroundColor: const Color(
            0xFFFE2C55,
          ).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoadingInfo
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  key: ValueKey('button'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 21),
                    SizedBox(width: 9),
                    Text(
                      'Get Video',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    final percent = (_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF25F4EE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Downloading ${_downloadingType == 'video' ? 'video' : 'audio'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF25F4EE),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              color: const Color(0xFF25F4EE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    final thumbnail = _videoInfo?['thumbnail']?.toString() ?? '';

    final title = _videoInfo?['title']?.toString().trim().isNotEmpty == true
        ? _videoInfo!['title'].toString()
        : 'Untitled Video';

    final uploader = _videoInfo?['uploader']?.toString() ?? 'unknown';
    final duration = _videoInfo?['duration'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Preview',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141417),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildThumbnail(thumbnail),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 17,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '@$uploader',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${duration}s',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDownloadButton(
                            icon: Icons.videocam_rounded,
                            title: 'MP4',
                            subtitle: 'Video',
                            primary: true,
                            loading: _isPreparingDownload,
                            onPressed:
                                (_isPreparingDownload || _downloadProgress > 0)
                                ? null
                                : _processVideoDownload,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDownloadButton(
                            icon: Icons.music_note_rounded,
                            title: 'MP3',
                            subtitle: 'Audio',
                            primary: false,
                            loading: false,
                            onPressed: _downloadProgress > 0
                                ? null
                                : _processAudioDownload,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return _thumbnailPlaceholder();
              },
            )
          else
            _thumbnailPlaceholder(),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 16),
                  SizedBox(width: 3),
                  Text(
                    'Preview',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: const Color(0xFF202025),
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          size: 48,
          color: Colors.white24,
        ),
      ),
    );
  }

  Widget _buildDownloadButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool primary,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    if (primary) {
      return SizedBox(
        height: 62,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFE2C55),
            disabledBackgroundColor: const Color(
              0xFFFE2C55,
            ).withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF25F4EE),
          side: BorderSide(
            color: const Color(0xFF25F4EE).withValues(alpha: 0.7),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101A1A),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFF25F4EE).withValues(alpha: 0.12),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF25F4EE)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Tip: Make sure the video URL is public and accessible before downloading.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
