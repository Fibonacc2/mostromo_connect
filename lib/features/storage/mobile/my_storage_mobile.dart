// lib/features/storage/mobile/my_storage_mobile.dart

import 'dart:ui'; // 🌟 YENİ EKLENDİ (Cam efekti için)
import 'package:flutter/services.dart'; // 🌟 YENİ EKLENDİ (Kopyalama işlemi için)
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
import 'package:shared_core/services/file_download_service.dart';

class MyStorageMobilePage extends StatefulWidget {
  const MyStorageMobilePage({super.key});

  @override
  State<MyStorageMobilePage> createState() => _MyStorageMobileState();
}

class _MyStorageMobileState extends State<MyStorageMobilePage> {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();

  late NavEventProvider _navEventProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavEventProvider>().addListener(_handleNavEvent);

      context.read<StorageViewModel>().setTrashMode(false);

      if (context.read<StorageViewModel>().allFolders.isEmpty &&
          context.read<StorageViewModel>().allFiles.isEmpty) {
        context.read<StorageViewModel>().fetchData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navEventProvider = context.read<NavEventProvider>();
  }

  void _handleNavEvent() {
    final nav = context.read<NavEventProvider>();
    if (nav.activeTab == 0 && mounted && _pageScrollController.hasClients) {
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
    _nameController.dispose();
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
              : _getAppBarTitle(viewModel),
        );

        final Widget? leadingWidget = isSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => viewModel.clearSelection(),
                tooltip: 'Seçimi İptal Et',
              )
            : (viewModel.isAtRoot
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => viewModel.goBack(),
                    ));

        final List<Widget> actionWidgets = isSelection
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _showCreateFolderDialog(context, viewModel),
                  tooltip: 'Yeni Klasör Oluştur',
                ),
                IconButton(
                  icon: viewModel.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: viewModel.isLoading
                      ? null
                      : () => viewModel.fetchData(),
                  tooltip: 'Senkronize Et',
                ),
              ];

        return PopScope(
          canPop: viewModel.isAtRoot,
          onPopInvoked: (didPop) {
            if (didPop) return;
            viewModel.goBack();
          },
          child: MostromoScaffold(
            title: titleWidget,
            controller: _pageScrollController,
            leading: leadingWidget,
            actions: actionWidgets,
            onRefresh: () => viewModel.fetchData(),
            floatingActionButton: !isSelection
                ? _buildUploadFab(context, viewModel.currentFolderId)
                : null,
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
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, StorageViewModel viewModel) {
    if (viewModel.isLoading &&
        viewModel.activeFiles.isEmpty &&
        viewModel.activeFolders.isEmpty) {
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
    combinedList.addAll(viewModel.activeFolders);

    final Map<String, List<FileItem>> groupedFiles = {};
    for (var file in viewModel.activeFiles) {
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

  String _getAppBarTitle(StorageViewModel viewModel) {
    if (viewModel.isAtRoot) return 'Dosyalarım';
    final currentFolder = viewModel.allFolders.firstWhere(
      (f) => f.folderId == viewModel.currentFolderId,
      orElse: () =>
          FolderItem(folderId: 0, folderName: 'Bilinmeyen', parentId: 0),
    );
    return currentFolder.folderName;
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
            viewModel.navigateToFolder(folder);
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
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Klasör boş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dosya eklemek için (+) butonunu kullanın\nveya yenilemek için aşağı çekin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => viewModel.fetchData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Senkronize Et'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFab(BuildContext context, int currentFolderId) {
    return FloatingActionButton(
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      onPressed: () {
        context.push('/upload_file', extra: currentFolderId);
      },
    );
  }

  Widget? _buildBottomActionbar(
    BuildContext context,
    StorageViewModel viewModel,
  ) {
    if (!viewModel.isSelectionMode) return null;

    final int totalSelected =
        viewModel.selectedFiles.length + viewModel.selectedFolders.length;
    final bool filesSelected = viewModel.selectedFiles.isNotEmpty;
    final bool foldersSelected = viewModel.selectedFolders.isNotEmpty;

    final bool canRename =
        (viewModel.selectedFolders.length == 1) && !filesSelected;
    final bool canShare =
        totalSelected ==
        1; // 🌟 YENİ: Sadece 1 öğe seçiliyken paylaşım yapılabilir

    List<Widget> actions = [];

    // 🌟 PAYLAŞ BUTONU
    if (canShare) {
      actions.add(
        _buildBottomActionItem(Icons.podcasts_rounded, 'Paylaş', () {
          final dynamic item = viewModel.selectedFiles.isNotEmpty
              ? viewModel.selectedFiles.first
              : viewModel.selectedFolders.first;
          _showMobileShareSheet(context, item, viewModel);
        }),
      );
    }

    if (canRename) {
      actions.add(
        _buildBottomActionItem(Icons.drive_file_rename_outline, 'Adlandır', () {
          final folderToRename = viewModel.selectedFolders.first;
          _showRenameFolderDialog(context, viewModel, folderToRename);
        }),
      );
    }

    if (filesSelected && !foldersSelected) {
      actions.add(
        _buildBottomActionItem(
          Icons.download,
          'İndir',
          () => _downloadSelectedFiles(context, viewModel),
        ),
      );
    }

    if (filesSelected || foldersSelected) {
      actions.add(
        _buildBottomActionItem(
          Icons.drive_file_move_outline,
          'Taşı',
          () => _showMoveDialog(context, viewModel),
        ),
      );
    }

    if (filesSelected || foldersSelected) {
      actions.add(
        _buildBottomActionItem(
          Icons.delete_outline,
          'Çöpe At',
          () => _deleteSelectedItems(context, viewModel),
        ),
      );
    }

    return BottomAppBar(
      surfaceTintColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions,
      ),
    );
  }

  Widget _buildBottomActionItem(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ThemeColors.primary),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: ThemeColors.primary),
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
              Icons.open_in_new,
              'Aç',
              () => _openFileViewer(context, file),
            ),
            // 🌟 YENİ PAYLAŞ MENÜSÜ EKLENDİ
            _buildActionTile(
              Icons.podcasts_rounded,
              'Paylaş',
              () => _showMobileShareSheet(context, file, viewModel),
            ),
            _buildActionTile(
              Icons.drive_file_rename_outline,
              'Yeniden Adlandır',
              () => _showRenameFileDialog(context, viewModel, file),
            ),
            _buildActionTile(
              Icons.download,
              'İndir',
              () => _downloadFile(context, file),
            ),
            _buildActionTile(
              Icons.info,
              'Detaylar',
              () => _showFileDetails(context, file),
            ),
            const Divider(height: 1),
            _buildActionTile(
              Icons.delete_outline,
              'Çöpe At',
              () => _deleteFile(context, viewModel, file),
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog(
    BuildContext context,
    StorageViewModel viewModel,
  ) {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Klasör Oluştur'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Klasör Adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                final folderName = _nameController.text.trim();
                if (folderName.isNotEmpty) {
                  Navigator.pop(context);
                  viewModel.createFolder(folderName);
                }
              },
              child: const Text('Oluştur'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, {int count = 1}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(count > 1 ? '$count Öğeyi Çöpe Taşı' : 'Dosyayı Çöpe Taşı'),
        content: Text(
          count > 1
              ? 'Seçili $count öğeyi Geri Dönüşüm Kutusuna taşımak istediğinize emin misiniz?'
              : 'Bu dosyayı Geri Dönüşüm Kutusuna taşımak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Çöpe At'),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(
    BuildContext context,
    StorageViewModel viewModel,
    FolderItem folder,
  ) {
    _nameController.text = folder.folderName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Klasörü Yeniden Adlandır'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Klasör Adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty && newName != folder.folderName) {
                  Navigator.pop(context);
                  viewModel.renameFolder(folder, newName);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void _showMoveDialog(BuildContext context, StorageViewModel viewModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final allFolders = viewModel.allFolders;
        final selectableFolders = allFolders.where((folder) {
          if (viewModel.selectedFolders.contains(folder)) return false;
          if (folder.folderId == 0) return true;
          if (folder.folderId == viewModel.currentFolderId) return false;
          return true;
        }).toList();

        if (!selectableFolders.any((f) => f.folderId == 0)) {
          selectableFolders.insert(
            0,
            FolderItem(folderId: 0, folderName: "Ana Dizin", parentId: -1),
          );
        }

        return AlertDialog(
          title: const Text('Taşınacak Klasörü Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: selectableFolders.length,
              itemBuilder: (context, index) {
                final folder = selectableFolders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(folder.folderName),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    viewModel.moveSelectedItems(folder.folderId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameFileDialog(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) {
    String extension = "";
    String nameWithoutExtension = file.fileName;

    if (file.fileName.contains('.')) {
      int dotIndex = file.fileName.lastIndexOf('.');
      if (dotIndex != -1) {
        nameWithoutExtension = file.fileName.substring(0, dotIndex);
        extension = file.fileName.substring(dotIndex);
      }
    }

    _nameController.text = nameWithoutExtension;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dosyayı Yeniden Adlandır'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Dosya Adı',
              suffixText: extension.isNotEmpty ? extension : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty && newName != nameWithoutExtension) {
                  Navigator.pop(context);
                  viewModel.renameFile(file, newName);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFile(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) async {
    final bool? confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true) return;
    viewModel.toggleFileSelection(file);
    await viewModel.moveToTrash();
  }

  Future<void> _deleteSelectedItems(
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

    await viewModel.moveToTrash();
  }

  Future<void> _downloadSelectedFiles(
    BuildContext context,
    StorageViewModel viewModel,
  ) async {
    int successCount = 0;
    int errorCount = 0;
    final filesToDownload = viewModel.selectedFiles.toList();

    if (filesToDownload.isEmpty) {
      viewModel.clearSelection();
      return;
    }

    for (var file in filesToDownload) {
      final result = await FileDownloadService.requestDownload(file);
      if (result == null) {
        successCount++;
      } else {
        errorCount++;
      }
    }
    viewModel.clearSelection();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successCount dosya indirme sırasına eklendi.${errorCount > 0 ? ' $errorCount dosyada hata oluştu.' : ''}',
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _downloadFile(BuildContext context, FileItem file) async {
    final result = await FileDownloadService.requestDownload(file);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? '"${file.fileName}" indirme işlemi başladı...'
                : 'Hata: $result',
          ),
          backgroundColor: result == null ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _openFileViewer(BuildContext context, FileItem file) {
    switch (file.fileType) {
      case 'media/img':
      case 'media/video':
        context.push('/media_viewer', extra: file);
        break;
      case 'document/pdf':
        context.push('/pdf_viewer', extra: file);
        break;
      case 'document/text':
      case 'code':
        context.push('/text_viewer', extra: file);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.fileName}" için görüntüleyici yok.'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : null;
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
    final bool hasUpdate =
        file.lastUpdated != null && file.lastUpdated!.isNotEmpty;
    final String dateString = hasUpdate ? file.lastUpdated! : file.createdAt;
    final String dateLabel = hasUpdate ? 'Güncellenme' : 'Oluşturulma';
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
            Text('$dateLabel: ${_formatDate(dateString)}'),
            if (file.webpUrl != null) const Text('WebP: Mevcut'),
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
    final bool hasUpdate =
        file.lastUpdated != null && file.lastUpdated!.isNotEmpty;
    final String dateString = hasUpdate ? file.lastUpdated! : file.createdAt;
    final String dateLabel = hasUpdate ? 'Güncellendi:' : 'Oluşturuldu:';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getFileTypeText(file.fileType)} • ${_formatFileSize(file.fileSize)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          '$dateLabel ${_formatDate(dateString)}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
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
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inDays == 0)
        return 'Bugün ${DateFormat('HH:mm').format(date)}';
      if (difference.inDays == 1)
        return 'Dün ${DateFormat('HH:mm').format(date)}';
      if (difference.inDays < 7) return '${difference.inDays} gün önce';
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // =====================================================================
  // 🌟 MOBİL İÇİN ÖZEL: KAYARAK AÇILAN PAYLAŞIM PANELİ (BOTTOM SHEET)
  // =====================================================================
  void _showMobileShareSheet(
    BuildContext context,
    dynamic item,
    StorageViewModel viewModel,
  ) {
    bool isLoading = true;
    String? currentLink;
    bool isPasswordEnabled = false;
    TextEditingController passwordController = TextEditingController();
    int expireHours = 0;

    void fetchCurrentInfo(StateSetter setState) async {
      final info = await viewModel.getShareLinkInfo(item);
      if (info != null) {
        currentLink = info['share_link'];
        isPasswordEnabled = info['has_password'] ?? false;
        if (isPasswordEnabled) passwordController.text = info['password'] ?? '';
      }
      setState(() => isLoading = false);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ThemeColors.background.withValues(alpha: 0.7),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) fetchCurrentInfo(setState);

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                margin: const EdgeInsets.only(top: kToolbarHeight),
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
                decoration: BoxDecoration(
                  color: ThemeColors.floatingPanelColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ThemeColors.captionText.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (isLoading)
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ThemeColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.podcasts_rounded,
                                color: ThemeColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Paylaş",
                                    style: TextStyle(
                                      color: ThemeColors.titleText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  Text(
                                    item is FolderItem
                                        ? "Klasör Paylaşımı"
                                        : "Dosya Paylaşımı",
                                    style: TextStyle(
                                      color: ThemeColors.captionText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ThemeColors.titleText.withValues(
                                alpha: 0.05,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lock_rounded,
                                        size: 20,
                                        color: ThemeColors.titleText,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Şifre Koruması",
                                        style: TextStyle(
                                          color: ThemeColors.titleText,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
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
                                const SizedBox(height: 16),
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  style: TextStyle(
                                    color: ThemeColors.titleText,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Bir şifre belirleyin",
                                    hintStyle: const TextStyle(
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    filled: true,
                                    fillColor: ThemeColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeColors.surface,
                            borderRadius: BorderRadius.circular(20),
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
                                  const SizedBox(width: 12),
                                  Text(
                                    "Geçerlilik",
                                    style: TextStyle(
                                      color: ThemeColors.titleText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
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

                        if (currentLink != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: ThemeColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ThemeColors.primary.withValues(
                                  alpha: 0.3,
                                ),
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
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
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
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: ThemeColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          children: [
                            if (currentLink != null) ...[
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: BorderSide(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
                                    setState(() => isLoading = true);
                                    await viewModel.revokeShareLink(item);
                                    if (sheetContext.mounted)
                                      Navigator.pop(sheetContext);
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Paylaşım durduruldu."),
                                        ),
                                      );
                                  },
                                  child: const Icon(Icons.block_rounded),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  if (isPasswordEnabled &&
                                      passwordController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Lütfen bir şifre girin!",
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => isLoading = true);
                                  final data = await viewModel
                                      .generateShareLink(
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
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Bağlantı güncellendi!",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                  } else {
                                    setState(() => isLoading = false);
                                  }
                                },
                                child: Text(
                                  currentLink == null
                                      ? "Bağlantı Oluştur"
                                      : "Ayarları Kaydet",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
