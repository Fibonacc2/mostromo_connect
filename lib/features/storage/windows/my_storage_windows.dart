// lib/features/storage/windows/my_storage_windows.dart

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'; // 🌟 YENİ: Fare Tuşlarını (kBackMouseButton) tanımak için!
import 'package:go_router/go_router.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';
import 'package:provider/provider.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../widgets/storage_header_widget.dart';
import '../widgets/storage_selection_bar.dart';
import '../widgets/storage_item_widget.dart';
import '../widgets/storage_info_panel.dart';
import '../widgets/upload_status_panel.dart';
import '../widgets/download_status_panel.dart';

class MyStorageWindowsPage extends StatefulWidget {
  const MyStorageWindowsPage({super.key});

  @override
  State<MyStorageWindowsPage> createState() => _MyStorageWindowsPageState();
}

class _MyStorageWindowsPageState extends State<MyStorageWindowsPage> {
  bool _isDragging = false;
  int _lastFolderId = -1;

  final FocusNode _focusNode = FocusNode();
  bool _isCtrlPressed = false;

  final GlobalKey _stackKey = GlobalKey();
  final Map<dynamic, GlobalKey> _itemKeys = {};
  Offset? _dragStart;
  Offset? _dragCurrent;
  Set<dynamic> _preDragSelection = {};

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageViewModel>().setTrashMode(false);
      if (context.read<StorageViewModel>().allFolders.isEmpty &&
          context.read<StorageViewModel>().allFiles.isEmpty) {
        context.read<StorageViewModel>().fetchData();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
    final viewModel = context.read<StorageViewModel>();
    if (_isCtrlPressed) {
      _preDragSelection = {
        ...viewModel.selectedFolders,
        ...viewModel.selectedFiles,
      };
    } else {
      _preDragSelection = {};
      viewModel.clearSelection();
      viewModel.closeInfoPanel();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragCurrent = details.localPosition;
    });
    _updateSelectionFromMarquee();
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
    _preDragSelection.clear();
  }

  void _updateSelectionFromMarquee() {
    if (_dragStart == null || _dragCurrent == null) return;
    final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
    final viewModel = context.read<StorageViewModel>();
    List<dynamic> intersectingItems = [];
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    _itemKeys.forEach((item, key) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          try {
            final itemRect =
                box.localToGlobal(Offset.zero, ancestor: stackBox) & box.size;
            if (rect.overlaps(itemRect)) intersectingItems.add(item);
          } catch (e) {}
        }
      }
    });
    viewModel.updateMarqueeSelection(
      intersectingItems,
      preDragSelection: _preDragSelection,
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset globalPosition,
    dynamic item,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset localOffset = overlay.globalToLocal(globalPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localOffset.dx, localOffset.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 12,
      color: ThemeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ThemeColors.titleText.withValues(alpha: 0.05)),
      ),
      items: [
        _buildDesktopMenuItem('open', Icons.open_in_new_rounded, 'Aç'),
        if (item is FileItem)
          _buildDesktopMenuItem('download', Icons.download_rounded, 'İndir'),

        _buildDesktopMenuItem('rename', Icons.edit_rounded, 'Yeniden Adlandır'),
        if (item is FileItem)
          _buildDesktopMenuItem(
            'share',
            Icons.link_rounded,
            'Bağlantıyı Paylaş',
          ),

        if (item is FolderItem)
          _buildDesktopMenuItem(
            'download_folder',
            Icons.archive_rounded,
            'ZIP Olarak İndir',
          ),

        if (item is FolderItem)
          _buildDesktopMenuItem(
            'share_folder',
            Icons.podcasts_rounded,
            'Klasörü Paylaş',
          ),
        const PopupMenuDivider(height: 1),
        _buildDesktopMenuItem(
          'trash',
          Icons.delete_rounded,
          'Çöpe At',
          isDestructive: true,
        ),
      ],
    ).then((value) {
      if (value != null) _handleMenuAction(value, item, context);
    });
  }

  void _showEmptySpaceMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset localOffset = overlay.globalToLocal(globalPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localOffset.dx, localOffset.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 12,
      color: ThemeColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ThemeColors.titleText.withValues(alpha: 0.05)),
      ),
      items: [
        _buildDesktopMenuItem('refresh', Icons.refresh_rounded, 'Yenile'),
        _buildDesktopMenuItem(
          'new_folder',
          Icons.create_new_folder_rounded,
          'Yeni Klasör',
        ),
        _buildDesktopMenuItem(
          'select_all',
          Icons.select_all_rounded,
          'Tümünü Seç',
        ),
        const PopupMenuDivider(height: 1),
        _buildDesktopMenuItem(
          'upload',
          Icons.cloud_upload_rounded,
          'Dosya Yükle',
        ),
      ],
    ).then((value) {
      final viewModel = context.read<StorageViewModel>();
      if (value == 'refresh')
        viewModel.fetchData();
      else if (value == 'new_folder')
        _showCreateFolderDialog(context);
      else if (value == 'upload')
        context.go('/upload');
      else if (value == 'select_all')
        viewModel.selectAll(isTrash: false);
    });
  }

  PopupMenuItem<String> _buildDesktopMenuItem(
    String value,
    IconData icon,
    String title, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive
                ? Colors.redAccent
                : ThemeColors.titleText.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.redAccent : ThemeColors.titleText,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, dynamic item, BuildContext context) {
    final viewModel = context.read<StorageViewModel>();

    if (viewModel.selectedFiles.isEmpty && viewModel.selectedFolders.isEmpty) {
      if (item is FolderItem)
        viewModel.toggleFolderSelection(item);
      else
        viewModel.toggleFileSelection(item as FileItem);
    }

    if (action == 'open') {
      viewModel.clearSelection();
      if (item is FolderItem)
        viewModel.navigateToFolder(item);
      else
        _openFileViewer(context, item as FileItem);
    } else if (action == 'trash') {
      _showTrashDialog(context, viewModel, singleItem: item);
    } else if (action == 'rename') {
      _showRenameDialog(context, item, viewModel);
    } else if (action == 'download') {
      viewModel.startDownload(item as FileItem);
    } else if (action == 'share') {
      _showShareDialog(context, item, viewModel);
    } else if (action == 'download_folder') {
      viewModel.startFolderDownload(item as FolderItem);
    } else if (action == 'share_folder') {
      _showShareDialog(context, item, viewModel);
    }
  }

  void _openFileViewer(BuildContext context, FileItem file) {
    final ext = file.fileExtension.toLowerCase();
    if (ext == 'pdf')
      context.push('/pdf_viewer', extra: file);
    else if (['txt', 'md', 'json'].contains(ext))
      context.push('/text_viewer', extra: file);
    else
      context.push('/media_viewer', extra: file);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StorageViewModel>();

    if (_lastFolderId != viewModel.currentFolderId) {
      _itemKeys.clear();
      _lastFolderId = viewModel.currentFolderId;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        setState(
          () => _isCtrlPressed = HardwareKeyboard.instance.isControlPressed,
        );
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyA &&
            _isCtrlPressed) {
          viewModel.selectAll(isTrash: false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          if (event.buttons == kBackMouseButton) {
            viewModel.goBack();
          } else if (event.buttons == kForwardMouseButton) {
            viewModel.goForward();
          }
        },
        child: DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) {
            setState(() => _isDragging = false);
            if (details.files.isNotEmpty) {
              viewModel.handlePaths(details.files.map((f) => f.path).toList());
              context.go('/upload');
            }
          },
          child: Scaffold(
            backgroundColor: ThemeColors.background,
            body: Stack(
              key: _stackKey,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      viewModel.clearSelection();
                      viewModel.closeInfoPanel();
                    },
                    onSecondaryTapUp: (details) =>
                        _showEmptySpaceMenu(context, details.globalPosition),
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: _handlePanEnd,
                    behavior: HitTestBehavior.translucent,
                    child: viewModel.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: ThemeColors.primary,
                            ),
                          )
                        : _buildGroupedDesktopGrid(viewModel),
                  ),
                ),

                if (_dragStart != null && _dragCurrent != null)
                  Positioned(
                    left: min(_dragStart!.dx, _dragCurrent!.dx),
                    top: min(_dragStart!.dy, _dragCurrent!.dy),
                    width: (_dragStart!.dx - _dragCurrent!.dx).abs(),
                    height: (_dragStart!.dy - _dragCurrent!.dy).abs(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ThemeColors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: ThemeColors.primary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: StorageHeaderWidget(
                    viewModel: viewModel,
                    onCreateFolderTap: () => _showCreateFolderDialog(context),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  top: 100,
                  bottom: 24,
                  right: viewModel.isInfoPanelOpen ? 24 : -300,
                  width: 250,
                  child: Material(
                    elevation: 24,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ThemeColors.floatingPanelColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: ThemeColors.titleText.withValues(alpha: 0.05),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: StorageInfoPanel(viewModel: viewModel),
                      ),
                    ),
                  ),
                ),

                StorageSelectionBar(
                  viewModel: viewModel,
                  onTrashTap: () => _showTrashDialog(context, viewModel),
                ),

                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(child: UploadStatusPanel(viewModel: viewModel)),
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: DownloadStatusPanel(viewModel: viewModel),
                ),

                if (_isDragging)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        color: ThemeColors.background.withValues(alpha: 0.6),
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: ThemeColors.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: ThemeColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.file_download_rounded,
                                        size: 80,
                                        color: ThemeColors.primary,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Mostromo'ya Yükle",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: ThemeColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedDesktopGrid(StorageViewModel viewModel) {
    final folders = viewModel.activeFolders;
    final files = viewModel.activeFiles;

    const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.25,
    );

    if (folders.isEmpty && files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                viewModel.searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.folder_open_rounded,
                size: 80,
                color: ThemeColors.captionText.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              viewModel.searchQuery.isNotEmpty
                  ? "\"${viewModel.searchQuery}\" için sonuç bulunamadı."
                  : "Bu klasör tamamen boş",
              style: TextStyle(
                fontSize: 18,
                color: ThemeColors.titleText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.searchQuery.isNotEmpty
                  ? "Farklı bir arama yapmayı deneyin."
                  : "Sağ tıklayarak yeni klasör açabilir veya dosya yükleyebilirsiniz.",
              style: TextStyle(fontSize: 14, color: ThemeColors.captionText),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 110)),
        if (folders.isNotEmpty) ...[
          _buildSliverSection(
            "Klasörler",
            folders,
            gridDelegate,
            true,
            viewModel,
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
        if (files.isNotEmpty)
          _buildSliverSection(
            "Dosyalar",
            files,
            gridDelegate,
            false,
            viewModel,
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildSliverSection(
    String title,
    List items,
    SliverGridDelegate delegate,
    bool isFolder,
    StorageViewModel viewModel,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.captionText,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          viewModel.isListView
              ? SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    final itemKey = _itemKeys.putIfAbsent(
                      item,
                      () => GlobalKey(),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: StorageItemWidget(
                        item: item,
                        isFolder: isFolder,
                        viewModel: viewModel,
                        itemKey: itemKey,
                        isCtrlPressed: _isCtrlPressed,
                        onSecondaryTap: (details) => _showContextMenu(
                          context,
                          details.globalPosition,
                          item,
                        ),
                        onDoubleTap: () {
                          if (isFolder)
                            viewModel.navigateToFolder(item);
                          else
                            _openFileViewer(context, item as FileItem);
                        },
                      ),
                    );
                  }, childCount: items.length),
                )
              : SliverGrid(
                  gridDelegate: delegate,
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = items[index];
                    final itemKey = _itemKeys.putIfAbsent(
                      item,
                      () => GlobalKey(),
                    );
                    return StorageItemWidget(
                      item: item,
                      isFolder: isFolder,
                      viewModel: viewModel,
                      itemKey: itemKey,
                      isCtrlPressed: _isCtrlPressed,
                      onSecondaryTap: (details) => _showContextMenu(
                        context,
                        details.globalPosition,
                        item,
                      ),
                      onDoubleTap: () {
                        if (isFolder)
                          viewModel.navigateToFolder(item);
                        else
                          _openFileViewer(context, item as FileItem);
                      },
                    );
                  }, childCount: items.length),
                ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final viewModel = context.read<StorageViewModel>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withValues(alpha: 0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: AlertDialog(
          backgroundColor: ThemeColors.floatingPanelColor,
          elevation: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.create_new_folder_rounded,
                  color: ThemeColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Yeni Klasör",
                style: TextStyle(
                  color: ThemeColors.titleText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: ThemeColors.titleText,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: "Örn: Tasarımlar",
              hintStyle: TextStyle(
                color: ThemeColors.captionText.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.folder_rounded,
                color: ThemeColors.captionText,
              ),
              filled: true,
              fillColor: ThemeColors.background.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                viewModel.createFolder(value.trim());
                Navigator.pop(context);
              }
            },
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "İptal",
                style: TextStyle(
                  color: ThemeColors.captionText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  viewModel.createFolder(controller.text.trim());
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Oluştur",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    dynamic item,
    StorageViewModel viewModel,
  ) {
    final bool isFolder = item is FolderItem;
    final controller = TextEditingController(
      text: isFolder ? item.folderName : (item as FileItem).fileName,
    );
    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withValues(alpha: 0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: AlertDialog(
          backgroundColor: ThemeColors.floatingPanelColor,
          elevation: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: ThemeColors.primary),
              const SizedBox(width: 12),
              Text(
                "Yeniden Adlandır",
                style: TextStyle(
                  color: ThemeColors.titleText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: ThemeColors.titleText,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: ThemeColors.background.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "İptal",
                style: TextStyle(
                  color: ThemeColors.captionText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (isFolder) {
                  viewModel.renameFolder(item, controller.text);
                } else {
                  viewModel.renameFile(item as FileItem, controller.text);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Kaydet",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrashDialog(
    BuildContext context,
    StorageViewModel viewModel, {
    dynamic singleItem,
  }) {
    final int deleteCount = singleItem != null
        ? 1
        : (viewModel.selectedFolders.length + viewModel.selectedFiles.length);
    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withValues(alpha: 0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: AlertDialog(
          backgroundColor: ThemeColors.floatingPanelColor,
          elevation: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Çöpe Taşı",
                style: TextStyle(
                  color: ThemeColors.titleText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Seçilen $deleteCount öğe Geri Dönüşüm Kutusu'na taşınacak. İstediğiniz zaman geri yükleyebilirsiniz.",
            style: TextStyle(color: ThemeColors.captionText, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "İptal",
                style: TextStyle(
                  color: ThemeColors.captionText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (singleItem != null) {
                  viewModel.clearSelection();
                  if (singleItem is FolderItem) {
                    viewModel.toggleFolderSelection(singleItem);
                  } else {
                    viewModel.toggleFileSelection(singleItem as FileItem);
                  }
                }
                viewModel.moveToTrash();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Çöpe Taşı",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 YENİ: GELİŞMİŞ PREMIUM PAYLAŞIM PENCERESİ
  void _showShareDialog(
    BuildContext context,
    dynamic item,
    StorageViewModel viewModel,
  ) {
    bool isLoading = true;
    String? currentLink;
    bool isPasswordEnabled = false;
    TextEditingController passwordController = TextEditingController();
    int expireHours = 0; // 0 = Sınırsız

    // Pencere açılırken mevcut ayarları sunucudan çeker
    void fetchCurrentInfo(StateSetter setState) async {
      final info = await viewModel.getShareLinkInfo(item);
      if (info != null) {
        currentLink = info['share_link'];
        isPasswordEnabled = info['has_password'] ?? false;
        if (isPasswordEnabled) passwordController.text = info['password'] ?? '';
      }
      setState(() => isLoading = false);
    }

    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              fetchCurrentInfo(setState);
              return const Center(child: CircularProgressIndicator());
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: AlertDialog(
                backgroundColor: ThemeColors.floatingPanelColor,
                elevation: 24,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: ThemeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Paylaş",
                      style: TextStyle(
                        color: ThemeColors.titleText,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bu içeriğe dışarıdan kimlerin, ne kadar süreyle erişebileceğini ayarlayın.",
                        style: TextStyle(
                          color: ThemeColors.captionText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 1. ŞİFRE KORUMASI
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ThemeColors.titleText.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 20,
                                      color: ThemeColors.titleText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Şifre Koruması",
                                      style: TextStyle(
                                        color: ThemeColors.titleText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: isPasswordEnabled,
                                  activeColor: ThemeColors.primary,
                                  onChanged: (val) => setState(() {
                                    isPasswordEnabled = val;
                                    if (!val) passwordController.clear();
                                  }),
                                ),
                              ],
                            ),
                            if (isPasswordEnabled) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: passwordController,
                                obscureText: true,
                                style: TextStyle(color: ThemeColors.titleText),
                                decoration: InputDecoration(
                                  hintText: "Bir şifre belirleyin...",
                                  filled: true,
                                  fillColor: ThemeColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. SÜRE SINIRI
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ThemeColors.titleText.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_rounded,
                                  size: 20,
                                  color: ThemeColors.titleText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Geçerlilik Süresi",
                                  style: TextStyle(
                                    color: ThemeColors.titleText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: expireHours,
                                dropdownColor: ThemeColors.surface,
                                style: TextStyle(
                                  color: ThemeColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text("Sınırsız"),
                                  ),
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text("1 Saat"),
                                  ),
                                  DropdownMenuItem(
                                    value: 24,
                                    child: Text("1 Gün"),
                                  ),
                                  DropdownMenuItem(
                                    value: 168,
                                    child: Text("1 Hafta"),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => expireHours = val!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. OLUŞTUR VE KOPYALA ALANI
                      if (currentLink != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentLink!,
                                  style: TextStyle(
                                    color: ThemeColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                color: ThemeColors.primary,
                                tooltip: "Kopyala",
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: currentLink!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Bağlantı kopyalandı!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.all(24),
                actions: [
                  if (currentLink != null)
                    TextButton.icon(
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text("Paylaşımı Kapat"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () async {
                        setState(() => isLoading = true);
                        await viewModel.revokeShareLink(item);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Paylaşım durduruldu.")),
                        );
                      },
                    ),
                  ElevatedButton.icon(
                    icon: Icon(
                      currentLink == null
                          ? Icons.add_link_rounded
                          : Icons.save_rounded,
                      size: 18,
                    ),
                    label: Text(
                      currentLink == null
                          ? "Bağlantı Oluştur"
                          : "Ayarları Kaydet",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (isPasswordEnabled &&
                          passwordController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Lütfen bir şifre girin!"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      setState(() => isLoading = true);
                      final data = await viewModel.generateShareLink(
                        item,
                        password: isPasswordEnabled
                            ? passwordController.text.trim()
                            : null,
                        expireHours: expireHours,
                      );
                      if (data != null) {
                        setState(() {
                          currentLink = data['share_link'];
                          isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Bağlantı başarıyla güncellendi!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
