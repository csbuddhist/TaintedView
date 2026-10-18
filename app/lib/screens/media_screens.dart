import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/media.dart';
import 'media_viewers.dart';

/// 图片或视频栏目：列出用户自建的分类。
class MediaCategoriesScreen extends StatelessWidget {
  const MediaCategoriesScreen({super.key, required this.kind});

  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).media;
    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _askName(context, title: '新建分类');
          if (name != null) store.createCategory(kind, name);
        },
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('新建分类'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final cats = store.categories(kind);
          if (cats.isEmpty) {
            return _Empty(icon: Icons.folder_open, text: '还没有分类\n点右下角「新建分类」开始添加${kind.label}');
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: cats.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = cats[i];
              return ListTile(
                leading: Icon(kind == MediaKind.image ? Icons.photo_album_outlined : Icons.video_collection_outlined),
                title: Text(c.name),
                subtitle: Text('${c.items.length} 项'),
                onTap: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => MediaCategoryScreen(categoryId: c.id))),
                trailing: PopupMenuButton<String>(
                  tooltip: '分类操作',
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await _askName(context, title: '重命名分类', initial: c.name);
                      if (name != null) store.renameCategory(c, name);
                    } else if (await _confirm(context, '删除分类「${c.name}」？', '分类里的 ${c.items.length} 项也会一并删除。')) {
                      await store.deleteCategory(c);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 一个分类的内容：图片显示为缩略图网格，视频显示为列表。
class MediaCategoryScreen extends StatefulWidget {
  const MediaCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<MediaCategoryScreen> createState() => _MediaCategoryScreenState();
}

class _MediaCategoryScreenState extends State<MediaCategoryScreen> {
  bool _importing = false;

  Future<void> _pickFiles(MediaCategory c) async {
    final store = AppScope.of(context).media;
    final messenger = ScaffoldMessenger.of(context);
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: c.kind == MediaKind.image ? FileType.image : FileType.video);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('无法打开文件选择器：$e')));
      return;
    }
    if (files.isEmpty) return;
    setState(() => _importing = true);
    var failed = 0;
    for (final f in files) {
      try {
        await store.addFile(c, f.name, f.readAsByteStream());
      } catch (e) {
        debugPrint('导入 ${f.name} 失败：$e');
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _importing = false);
    final ok = files.length - failed;
    messenger.showSnackBar(SnackBar(content: Text(failed == 0 ? '已添加 $ok 项' : '已添加 $ok 项，$failed 项导入失败')));
  }

  Future<void> _addLink(MediaCategory c) async {
    final result = await showDialog<(Uri, String)>(
      context: context,
      builder: (_) => _LinkDialog(kind: c.kind),
    );
    if (result != null && mounted) AppScope.of(context).media.addLink(c, result.$1, name: result.$2);
  }

  void _showAddSheet(MediaCategory c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text('从本地选择${c.kind.label}'),
              subtitle: const Text('可多选，文件会复制到应用内'),
              onTap: () {
                Navigator.pop(sheet);
                _pickFiles(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text('添加${c.kind.label}链接'),
              subtitle: const Text('http / https 地址，查看时需联网'),
              onTap: () {
                Navigator.pop(sheet);
                _addLink(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _itemMenu(MediaCategory c, MediaItem item) async {
    final store = AppScope.of(context).media;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: item.isLink ? Text(item.url!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(sheet, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final name = await _askName(context, title: '重命名', initial: item.name, label: '名称');
      if (name != null) store.renameItem(item, name);
    } else if (await _confirm(context, '删除「${item.name}」？', item.isLink ? '只删除这条链接。' : '会删除应用内保存的副本，不影响原文件。')) {
      await store.removeItem(c, item);
    }
  }

  void _open(MediaCategory c, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => c.kind == MediaKind.image
            ? ImageViewerScreen(items: List.of(c.items), initialIndex: index)
            : VideoPlayerScreen(item: c.items[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).media;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.category(widget.categoryId);
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const _Empty(icon: Icons.folder_off, text: '分类已删除'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(c.name),
            bottom: _importing
                ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
                : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _importing ? null : () => _showAddSheet(c),
            icon: const Icon(Icons.add),
            label: Text('添加${c.kind.label}'),
          ),
          body: c.items.isEmpty
              ? _Empty(icon: Icons.add_photo_alternate_outlined, text: '这个分类还是空的\n可以从本地选择${c.kind.label}，或添加链接')
              : c.kind == MediaKind.image
              ? _imageGrid(c)
              : _videoList(c),
        );
      },
    );
  }

  Widget _imageGrid(MediaCategory c) {
    final store = AppScope.of(context).media;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 88),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: c.items.length,
      itemBuilder: (context, i) {
        final item = c.items[i];
        return Semantics(
          label: item.name,
          button: true,
          child: GestureDetector(
            onTap: () => _open(c, i),
            onLongPress: () => _itemMenu(c, item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: mediaImage(store, item, fit: BoxFit.cover, cacheWidth: 320),
                ),
                if (item.isLink)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(Icons.link, size: 18, color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _videoList(MediaCategory c) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: c.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = c.items[i];
        return ListTile(
          leading: Icon(item.isLink ? Icons.ondemand_video : Icons.movie_outlined),
          title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: item.isLink ? Text(item.url!, maxLines: 1, overflow: TextOverflow.ellipsis) : const Text('本地视频'),
          onTap: () => _open(c, i),
          onLongPress: () => _itemMenu(c, item),
          trailing: IconButton(tooltip: '更多操作', icon: const Icon(Icons.more_vert), onPressed: () => _itemMenu(c, item)),
        );
      },
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.kind});

  final MediaKind kind;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = parseMediaLink(_url.text);
    if (uri == null) {
      setState(() => _error = '请输入有效的 http / https 链接');
      return;
    }
    Navigator.pop(context, (uri, _name.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('添加${widget.kind.label}链接'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: '链接地址',
              hintText: widget.kind == MediaKind.image ? 'https://…/photo.jpg' : 'https://…/video.mp4',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称（可选）'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, {required String title, String initial = '', String label = '分类名称'}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial, label: label),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, required this.label});

  final String title;
  final String initial;
  final String label;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
      ],
    ),
  );
  return ok ?? false;
}
