import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../app_scope.dart';
import '../data/media.dart';

/// 本地或网络图片；加载失败时显示占位图标。
Widget mediaImage(MediaStore store, MediaItem item, {BoxFit? fit, int? cacheWidth}) {
  Widget error(BuildContext context, Object e, StackTrace? _) =>
      Center(child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.outline));
  final file = store.fileOf(item);
  if (file != null) return Image.file(file, fit: fit, cacheWidth: cacheWidth, errorBuilder: error);
  return Image.network(
    item.url!,
    fit: fit,
    cacheWidth: cacheWidth,
    errorBuilder: error,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

/// 全屏看图：左右滑动切换，双指缩放。
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.items, this.initialIndex = 0});

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).media;
    final item = widget.items[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(child: Text('${_index + 1} / ${widget.items.length}')),
          const SizedBox(width: 16),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 5,
          child: SizedBox.expand(child: mediaImage(store, widget.items[i], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

/// 播放本地或网络视频。
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.item});

  final MediaItem item;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_video == null) _init();
  }

  Future<void> _init() async {
    final file = AppScope.of(context).media.fileOf(widget.item);
    final video = file != null
        ? VideoPlayerController.file(file)
        : VideoPlayerController.networkUrl(Uri.parse(widget.item.url!));
    _video = video;
    try {
      await video.initialize();
    } catch (e) {
      debugPrint('视频加载失败：$e');
      if (mounted) setState(() => _error = '视频无法播放');
      return;
    }
    if (!mounted) return;
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        aspectRatio: video.value.aspectRatio,
        allowedScreenSleep: false,
      );
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? _errorView()
              : _chewie == null
              ? const CircularProgressIndicator()
              : Chewie(controller: _chewie!),
        ),
      ),
    );
  }

  Widget _errorView() {
    final url = widget.item.url;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            url == null ? '$_error，文件可能已损坏或格式不受支持。' : '$_error。请确认已联网，并且链接直接指向视频文件（如 .mp4）；网页播放页链接可以用浏览器打开。',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          if (url != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('在浏览器中打开'),
            ),
          ],
        ],
      ),
    );
  }
}
