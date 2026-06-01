// lib/features/storage/mobile/trash_mobile_page.dart

import 'package:common_ui/views/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:mostromo_connect/core/nav_event_provider.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';
import 'dart:math';
import 'package:provider/provider.dart';

import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';

class TrashMobilePage extends StatefulWidget {
  const TrashMobilePage({super.key});

  @override
  State<TrashMobilePage> createState() => _TrashMobilePageState();
}

class _TrashMobilePageState extends State<TrashMobilePage> {
  final ScrollController _pageScrollController = ScrollController();
  late NavEventProvider _navEventProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavEventProvider>().addListener(_handleNavEvent);
      // 🌟 Sayfa açılır açılmaz ViewModel'i ÇÖP KUTUSU Moduna geçiririz
      context.read<StorageViewModel>().setTrashMode(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navEventProvider = context.read<NavEventProvider>();
  }

  void _handleNavEvent() {
    final nav = context.read<NavEventProvider>();
    if (nav.activeTab == 2 && mounted && _pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _navEventProvider.removeListener(_handleNavEvent);
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StorageViewModel>(
      builder: (context, viewModel, child) {
        final bool isSelection = viewModel.isSelectionMode;

        final Widget titleWidget = Text(
          isSelection
              ? '${viewModel.selectedFiles.length + viewModel.selectedFolders.length} öğe seçildi'
              : 'Geri Dönüşüm Kutusu',
        );

        final Widget? leadingWidget = isSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => viewModel.clearSelection(),
                tooltip: 'Seçimi İptal Et',
              )
            : null;

        return MostromoScaffold(
          title: titleWidget,
          controller: _pageScrollController,
          leading: leadingWidget,
          actions: const [], // Çöpte ekstra üst ikon yok
          onRefresh: () => viewModel.fetchData(),
          // 🌟 Çöpte FAB (Yükleme butonu) olmaz
          floatingActionButton: null,
          bottomBar: _buildBottomActionbar(context, viewModel),
          body: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: viewModel.syncStatus.isNotEmpty
                    ? _buildSyncStatus(viewModel.syncStatus)
                    : const SizedBox.shrink(),
              ),
              _buildContent(context, viewModel),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, StorageViewModel viewModel) {
    if (viewModel.isLoading &&
        viewModel.trashFiles.isEmpty &&
        viewModel.trashFolders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<dynamic> items = _buildCombinedList(viewModel);

    if (items.isEmpty) {
      return _buildEmptyState(viewModel);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: viewModel.isSelectionMode
          ? const EdgeInsets.only(bottom: 100)
          : const EdgeInsets.only(bottom: 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is FolderItem)
          return _buildFolderItem(context, viewModel, item);
        if (item is FileItem) return _buildFileItem(context, viewModel, item);
        if (item is String) return _buildGroupHeader(item);
        return const SizedBox.shrink();
      },
    );
  }

  List<dynamic> _buildCombinedList(StorageViewModel viewModel) {
    final List<dynamic> combinedList = [];
    combinedList.addAll(viewModel.trashFolders); // 🌟 Çöpteki klasörler

    final Map<String, List<FileItem>> groupedFiles = {};
    for (var file in viewModel.trashFiles) {
      // 🌟 Çöpteki dosyalar
      try {
        final date = DateTime.parse(file.createdAt);
        final key = _getGroupKey(date);
        if (groupedFiles[key] == null) groupedFiles[key] = [];
        groupedFiles[key]!.add(file);
      } catch (e) {
        if (groupedFiles['Diğer'] == null) groupedFiles['Diğer'] = [];
        groupedFiles['Diğer']!.add(file);
      }
    }

    groupedFiles.forEach((key, filesInGroup) {
      combinedList.add(key);
      combinedList.addAll(filesInGroup);
    });
    return combinedList;
  }

  Widget _buildSyncStatus(String syncStatus) {
    final statusColor = syncStatus.contains('Hata') ? Colors.red : Colors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: statusColor.withAlpha(25),
      child: Text(
        syncStatus,
        style: TextStyle(
          fontSize: 12,
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildFolderItem(
    BuildContext context,
    StorageViewModel viewModel,
    FolderItem folder,
  ) {
    final isSelected = viewModel.selectedFolders.contains(folder);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder, color: Colors.blue, size: 20),
        ),
        title: Text(
          folder.folderName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        trailing: viewModel.isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (val) => viewModel.toggleFolderSelection(folder),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        selected: isSelected,
        onLongPress: () {
          viewModel.toggleFolderSelection(folder);
        },
        onTap: () {
          if (viewModel.isSelectionMode) {
            viewModel.toggleFolderSelection(folder);
          } else {
            // Çöpteki klasör açılamaz, sadece seçilir
            viewModel.toggleFolderSelection(folder);
          }
        },
      ),
    );
  }

  Widget _buildFileItem(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) {
    final isSelected = viewModel.selectedFiles.contains(file);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _buildFileIcon(file),
        title: Text(
          file.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: _buildFileSubtitle(file),
        trailing: viewModel.isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (val) => viewModel.toggleFileSelection(file),
              )
            : const Icon(Icons.more_vert, size: 20, color: Colors.grey),
        selected: isSelected,
        onLongPress: () {
          viewModel.toggleFileSelection(file);
        },
        onTap: () {
          if (viewModel.isSelectionMode) {
            viewModel.toggleFileSelection(file);
          } else {
            _showFileOptions(context, viewModel, file);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(StorageViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Çöp kutusu boş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildBottomActionbar(
    BuildContext context,
    StorageViewModel viewModel,
  ) {
    if (!viewModel.isSelectionMode) return null;

    return BottomAppBar(
      surfaceTintColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomActionItem(
            Icons.restore_page_rounded,
            'Geri Yükle',
            Colors.green,
            () => viewModel.restoreSelected(),
          ),
          _buildBottomActionItem(
            Icons.delete_forever_rounded,
            'Kalıcı Sil',
            Colors.redAccent,
            () => _deletePermanently(context, viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileOptions(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _getFileIcon(file.fileType),
                color: _getFileColor(file.fileType),
              ),
              title: Text(file.fileName, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${_formatFileSize(file.fileSize)} • ${_formatDate(file.lastUpdated ?? file.createdAt)}',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              Icons.info,
              'Detaylar',
              () => _showFileDetails(context, file),
            ),
            _buildActionTile(Icons.restore_page_rounded, 'Geri Yükle', () {
              viewModel.toggleFileSelection(file);
              viewModel.restoreSelected();
            }, color: Colors.green),
            const Divider(height: 1),
            _buildActionTile(
              Icons.delete_forever_rounded,
              'Kalıcı Sil',
              () => _deleteSinglePermanently(context, viewModel, file),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSinglePermanently(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) async {
    final bool? confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true) return;
    viewModel.toggleFileSelection(file);
    await viewModel.deletePermanently();
  }

  Future<void> _deletePermanently(
    BuildContext context,
    StorageViewModel viewModel,
  ) async {
    final count =
        viewModel.selectedFiles.length + viewModel.selectedFolders.length;
    if (count == 0) return;
    final bool? confirmed = await _showDeleteConfirmation(
      context,
      count: count,
    );
    if (confirmed != true) return;
    await viewModel.deletePermanently();
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, {int count = 1}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Kalıcı Olarak Sil',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          count > 1
              ? 'Seçili $count öğeyi sunucudan kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem asla geri alınamaz!'
              : 'Bu dosyayı sunucudan kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem asla geri alınamaz!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text(
              'Kalıcı Sil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showFileDetails(BuildContext context, FileItem file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tür: ${file.fileType}'),
            Text('Boyut: ${_formatFileSize(file.fileSize)}'),
            Text('Tarih: ${_formatDate(file.createdAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _getGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final checkDate = DateTime(date.year, date.month, date.day);
    if (checkDate == today) return 'Bugün';
    if (checkDate == yesterday) return 'Dün';
    final difference = today.difference(checkDate).inDays;
    if (difference < 7) return 'Bu Hafta';
    if (difference < 30) return 'Bu Ay';
    return DateFormat.yMMMM('tr_TR').format(date);
  }

  Widget _buildFileIcon(FileItem file) {
    final color = _getFileColor(file.fileType);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_getFileIcon(file.fileType), color: color, size: 20),
    );
  }

  Widget _buildFileSubtitle(FileItem file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getFileTypeText(file.fileType)} • ${_formatFileSize(file.fileSize)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text('Çöpte', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
      ],
    );
  }

  String _getFileTypeText(String fileType) {
    return fileType.split('/').last.toUpperCase();
  }

  IconData _getFileIcon(String fileType) {
    const icons = {
      'media/img': Icons.image,
      'media/video': Icons.videocam,
      'media/audio': Icons.audiotrack,
      'document/pdf': Icons.picture_as_pdf,
      'document/word': Icons.description,
      'document/excel': Icons.table_chart,
      'document/powerpoint': Icons.slideshow,
      'document/text': Icons.text_snippet,
      'archive': Icons.archive,
      'code': Icons.code,
    };
    return icons[fileType] ?? Icons.insert_drive_file;
  }

  Color _getFileColor(String fileType) {
    const colors = {
      'media/img': Colors.green,
      'media/video': Colors.orange,
      'media/audio': Colors.purple,
      'document/pdf': Colors.red,
      'document/word': Colors.blue,
      'document/excel': Colors.green,
      'document/powerpoint': Colors.orange,
      'archive': Colors.brown,
      'code': Colors.black,
    };
    return colors[fileType] ?? Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    final digitGroups = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, digitGroups)).toStringAsFixed(1)} ${units[digitGroups]}";
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
