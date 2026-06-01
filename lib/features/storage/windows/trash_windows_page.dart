// lib/features/storage/windows/trash_windows_page.dart

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';
import 'package:provider/provider.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';

import '../widgets/storage_info_panel.dart';

class TrashWindowsPage extends StatefulWidget {
  const TrashWindowsPage({super.key});

  @override
  State<TrashWindowsPage> createState() => _TrashWindowsPageState();
}

class _TrashWindowsPageState extends State<TrashWindowsPage> {
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
        side: BorderSide(color: ThemeColors.titleText.withOpacity(0.05)),
      ),
      items: [
        _buildDesktopMenuItem(
          'restore',
          Icons.restore_page_rounded,
          'Geri Yükle',
        ),
        const PopupMenuDivider(height: 1),
        _buildDesktopMenuItem(
          'delete',
          Icons.delete_forever_rounded,
          'Kalıcı Olarak Sil',
          isDestructive: true,
        ),
      ],
    ).then((value) {
      if (value != null) _handleMenuAction(value, item, context);
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
                : ThemeColors.titleText.withOpacity(0.7),
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

    if (action == 'restore') {
      viewModel.restoreSelected();
    } else if (action == 'delete') {
      _showDeleteDialog(context, viewModel, singleItem: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StorageViewModel>();

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
          viewModel.selectAll(isTrash: true); // 🌟 GÜNCELLENDİ
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
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
                    color: ThemeColors.primary.withOpacity(0.15),
                    border: Border.all(color: ThemeColors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildGlassHeader(viewModel),
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
                shadowColor: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeColors.floatingPanelColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: ThemeColors.titleText.withOpacity(0.05),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: StorageInfoPanel(viewModel: viewModel),
                  ),
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: viewModel.isSelectionMode ? 32 : -100,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 16,
                  shadowColor: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  color: ThemeColors.floatingPanelColor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ThemeColors.titleText.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => viewModel.clearSelection(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${viewModel.selectedFolders.length + viewModel.selectedFiles.length} Öğe Seçildi",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ThemeColors.titleText,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(
                          width: 1,
                          height: 24,
                          color: ThemeColors.captionText.withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () => viewModel.selectAll(isTrash: true),
                          icon: const Icon(Icons.select_all_rounded),
                          label: const Text("Tümünü Seç"),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.restore_page_rounded,
                            color: Colors.green,
                          ),
                          onPressed: () => viewModel.restoreSelected(),
                          tooltip: "Geri Yükle",
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              _showDeleteDialog(context, viewModel),
                          tooltip: "Kalıcı Sil",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassHeader(StorageViewModel viewModel) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15 * ThemeColors.glassBlurOpacity,
          sigmaY: 15 * ThemeColors.glassBlurOpacity,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: ThemeColors.sidePanelColor.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: ThemeColors.titleText.withOpacity(0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                "Geri Dönüşüm Kutusu",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.titleText,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Container(
                  height: 44,
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: TextField(
                    onChanged: (value) => viewModel.setSearchQuery(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.titleText,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: ThemeColors.titleText.withOpacity(0.04),
                      hintText: "Çöp kutusunda ara...",
                      hintStyle: TextStyle(
                        color: ThemeColors.captionText.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: ThemeColors.captionText,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: ThemeColors.titleText.withOpacity(0.05),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: ThemeColors.primary.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedDesktopGrid(StorageViewModel viewModel) {
    // 🌟 GÜNCELLENDİ: Sadece çöpteki öğeleri alır
    final folders = viewModel.trashFolders;
    final files = viewModel.trashFiles;

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
                color: ThemeColors.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 80,
                color: ThemeColors.captionText.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Geri dönüşüm kutusu tamamen boş",
              style: TextStyle(
                fontSize: 18,
                color: ThemeColors.titleText,
                fontWeight: FontWeight.bold,
              ),
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
          SliverGrid(
            gridDelegate: delegate,
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              final String name = isFolder ? item.folderName : item.fileName;
              final appearance = isFolder
                  ? (Icons.folder_rounded, Colors.orangeAccent)
                  : _getFileAppearance(item.fileExtension, name);
              return _buildGridItem(
                item: item,
                name: name,
                icon: appearance.$1,
                iconColor: appearance.$2,
                isFolder: isFolder,
                viewModel: viewModel,
              );
            }, childCount: items.length),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem({
    required dynamic item,
    required String name,
    required IconData icon,
    required Color iconColor,
    required bool isFolder,
    required StorageViewModel viewModel,
  }) {
    final bool isActive = viewModel.activeItem == item;
    final bool isSelected = isFolder
        ? viewModel.selectedFolders.contains(item)
        : viewModel.selectedFiles.contains(item);
    final itemKey = _itemKeys.putIfAbsent(item, () => GlobalKey());

    return GestureDetector(
      key: itemKey,
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition, item),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeColors.primary.withOpacity(0.08)
                  : (isActive
                        ? iconColor.withOpacity(0.08)
                        : ThemeColors.surface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? ThemeColors.primary
                    : (isActive
                          ? iconColor.withOpacity(0.5)
                          : ThemeColors.titleText.withOpacity(0.05)),
                width: isSelected ? 2 : (isActive ? 2 : 1),
              ),
              boxShadow: [
                if (isActive || isSelected)
                  BoxShadow(
                    color: isSelected
                        ? ThemeColors.primary.withOpacity(0.15)
                        : iconColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                hoverColor: iconColor.withOpacity(0.05),
                onTap: () {
                  if (_isCtrlPressed) {
                    if (isFolder)
                      viewModel.toggleFolderSelection(item);
                    else
                      viewModel.toggleFileSelection(item);
                  } else {
                    if (viewModel.isSelectionMode) viewModel.clearSelection();
                    viewModel.selectItem(item);
                  }
                },
                onDoubleTap: () {}, // 🌟 GÜNCELLENDİ: Çöpteki dosya açılamaz
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 36, color: iconColor),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ThemeColors.titleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ThemeColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _getFileAppearance(String extension, String fileName) {
    String ext = extension.toLowerCase().replaceAll('.', '').trim();
    if (ext.isEmpty && fileName.contains('.'))
      ext = fileName.split('.').last.toLowerCase().trim();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return (Icons.image_rounded, Colors.purpleAccent);
      case 'pdf':
        return (Icons.picture_as_pdf_rounded, Colors.redAccent);
      case 'mp4':
      case 'mov':
      case 'avi':
        return (Icons.video_file_rounded, Colors.deepOrangeAccent);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return (Icons.table_view_rounded, Colors.green);
      case 'doc':
      case 'docx':
        return (Icons.description_rounded, Colors.blue);
      case 'zip':
      case 'rar':
      case '7z':
        return (Icons.folder_zip_rounded, Colors.brown);
      case 'txt':
      case 'md':
      case 'json':
      case 'html':
      case 'css':
      case 'js':
      case 'php':
        return (Icons.code_rounded, Colors.teal);
      default:
        return (Icons.insert_drive_file_rounded, ThemeColors.captionText);
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    StorageViewModel viewModel, {
    dynamic singleItem,
  }) {
    final int deleteCount = singleItem != null
        ? 1
        : (viewModel.selectedFolders.length + viewModel.selectedFiles.length);

    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withOpacity(0.5),
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
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Kalıcı Olarak Sil",
                style: TextStyle(
                  color: ThemeColors.titleText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Seçilen $deleteCount öğe sunucudan tamamen silinecek. Bu işlem asla geri alınamaz! Emin misiniz?",
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
                  if (singleItem is FolderItem)
                    viewModel.toggleFolderSelection(singleItem);
                  else
                    viewModel.toggleFileSelection(singleItem as FileItem);
                }
                viewModel.deletePermanently(); // 🌟 GÜNCELLENDİ
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
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
                "Kalıcı Sil",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
