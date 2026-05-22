import 'package:common_ui/views/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:mostromo_connect/core/nav_event_provider.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';
import 'dart:math';
import 'package:provider/provider.dart';

// Modelleri ve Servisleri import et
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';
import 'package:shared_core/services/file_download_service.dart';

import 'package:shared_core/services/upload_file_service.dart';

class MyStorageMobilePage extends StatefulWidget {
  const MyStorageMobilePage({super.key});

  @override
  State<MyStorageMobilePage> createState() => _MyStorageMobileState();
}

class _MyStorageMobileState extends State<MyStorageMobilePage> {
  // ✅ GÜNCELLENDİ: Bu controller artık hem klasör hem dosya adlandırma için ortak
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();

  late NavEventProvider _navEventProvider;

  @override
  void initState() {
    super.initState();
    // ✅ 2. Navigasyon olaylarını dinle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavEventProvider>().addListener(_handleNavEvent);
    });
  }

  // ✅ 3. Referansı widget henüz aktifken (context güvenliyken) kaydedin
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navEventProvider = context.read<NavEventProvider>();
  }

  void _handleNavEvent() {
    final nav = context.read<NavEventProvider>();
    // Eğer bu sekmedeysek ve tekrar basıldıysa üste git
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

  // --- 1. ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    return Consumer<StorageViewModel>(
      builder: (context, viewModel, child) {
        // AppBar içeriklerini seçim moduna ve klasör derinliğine göre burada hazırlıyoruz
        final bool isSelection = viewModel.isSelectionMode;

        // Başlık
        final Widget titleWidget = Text(
          isSelection
              ? '${viewModel.selectedFiles.length + viewModel.selectedFolders.length} öğe seçildi'
              : _getAppBarTitle(viewModel),
        );

        // Sol Buton (Leading)
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

        // Sağ Butonlar (Actions)
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
            // FAB: Seçim modunda gizlenir
            floatingActionButton: !isSelection
                ? _buildUploadFab(context, viewModel.currentFolderId)
                : null,
            // Alt Menü: Sadece seçim modunda görünür
            bottomBar: _buildBottomActionbar(context, viewModel),
            body: Column(
              children: [
                // Durum çubuğu (Senkronizasyon mesajları)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: viewModel.syncStatus.isNotEmpty
                      ? _buildSyncStatus(viewModel.syncStatus)
                      : const SizedBox.shrink(),
                ),
                // Ana Liste İçeriği
                _buildContent(context, viewModel),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 3. ANA İÇERİK (LİSTE) ---
  Widget _buildContent(BuildContext context, StorageViewModel viewModel) {
    if (viewModel.isLoading &&
        viewModel.visibleFiles.isEmpty &&
        viewModel.visibleFolders.isEmpty) {
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

    // RefreshIndicator'ı MostromoScaffold'un CustomScrollView'u ile
    // uyumlu çalışması için burada ListView'ı sarmalıyoruz.
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

  // Verileri tarih gruplarıyla birleştiren eksik metod
  List<dynamic> _buildCombinedList(StorageViewModel viewModel) {
    final List<dynamic> combinedList = [];
    combinedList.addAll(viewModel.visibleFolders);

    final Map<String, List<FileItem>> groupedFiles = {};
    for (var file in viewModel.visibleFiles) {
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
  /*
  // Tarih gruplama anahtarı
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
*/
  /* 
 Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
    );
  }
*/

  // --- 2. YARDIMCI METODLAR ---

  // AppBar başlığını belirleyen eksik metod
  String _getAppBarTitle(StorageViewModel viewModel) {
    if (viewModel.isAtRoot) return 'Dosyalarım';
    final currentFolder = viewModel.allFolders.firstWhere(
      (f) => f.folderId == viewModel.currentFolderId,
      orElse: () =>
          FolderItem(folderId: 0, folderName: 'Bilinmeyen', parentId: 0),
    );
    return currentFolder.folderName;
  }

  // Senkronizasyon durum çubuğu
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

  // --- 4. LİSTE ELEMANLARI (KLASÖR, DOSYA, BOŞ SAYFA, BAŞLIK) ---

  /// Tarih grupları için başlık
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

  /// Klasör listesi elemanını çizer
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

  /// Dosya listesi elemanını çizer
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
            _showFileOptions(context, viewModel, file); // Menüyü aç
          }
        },
      ),
    );
  }

  /// Boş klasör ekranı
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

  // --- 5. EYLEM BUTONLARI (FAB, BOTTOM BAR) ---

  /// Yükleme (Upload) Butonu
  Widget _buildUploadFab(BuildContext context, int currentFolderId) {
    return FloatingActionButton(
      backgroundColor: Colors.blue, // ThemeColors.buttonPrimary kullanabilirsin
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      onPressed: () {
        context.push('/upload_file', extra: currentFolderId);
      },
    );
  }

  /// Çoklu seçim alt eylem çubuğu
  Widget? _buildBottomActionbar(
    BuildContext context,
    StorageViewModel viewModel,
  ) {
    if (!viewModel.isSelectionMode) return null;

    final bool filesSelected = viewModel.selectedFiles.isNotEmpty;
    final bool foldersSelected = viewModel.selectedFolders.isNotEmpty;
    // Sadece 1 KLASÖR seçiliyse ve HİÇ dosya seçili değilse Adlandır'ı göster
    final bool canRename =
        (viewModel.selectedFolders.length == 1) && !filesSelected;

    List<Widget> actions = [];

    // --- SENARYO 1: "Yeniden Adlandır" (Sadece 1 klasör seçili)
    if (canRename) {
      actions.add(
        _buildBottomActionItem(Icons.drive_file_rename_outline, 'Adlandır', () {
          // Seçili olan o tek klasörü al
          final folderToRename = viewModel.selectedFolders.first;
          _showRenameFolderDialog(context, viewModel, folderToRename);
        }),
      );
    }

    // --- SENARYO 2: "İndir" (En az 1 dosya seçili VE hiç klasör seçili değil)
    if (filesSelected && !foldersSelected) {
      actions.add(
        _buildBottomActionItem(
          Icons.download,
          'İndir',
          () => _downloadSelectedFiles(context, viewModel),
        ),
      );
    }
    // --- SENARYO 3: "Taşı"
    if (filesSelected || foldersSelected) {
      actions.add(
        _buildBottomActionItem(Icons.drive_file_move_outline, 'Taşı', () {
          // Taşıma diyalogunu aç
          _showMoveDialog(context, viewModel);
        }),
      );
    }

    // --- SENARYO 3: "Sil" (Her zaman, yeter ki bir şey seçili olsun)
    if (filesSelected || foldersSelected) {
      actions.add(
        _buildBottomActionItem(
          Icons.delete_outline,
          'Sil',
          () => _deleteSelectedItems(context, viewModel),
        ),
      );
    }

    return BottomAppBar(
      surfaceTintColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions, // Dinamik olarak oluşturulan butonları ekle
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
            Icon(icon),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // --- 6. DİYALOGLAR VE MENÜLER (BOTTOM SHEET) ---

  /// Tekil dosya menüsünü gösterir
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
              () => _openFileViewer(context, file), // Yönlendiriciyi çağır
            ),
            _buildActionTile(
              Icons.drive_file_rename_outline,
              'Yeniden Adlandır',
              () => _showRenameFileDialog(context, viewModel, file),
            ),
            _buildActionTile(
              Icons.download,
              'İndir',
              () => _downloadFile(context, file), // Tekil indirme
            ),
            _buildActionTile(
              Icons.info,
              'Detaylar',
              () => _showFileDetails(context, file),
            ),
            const Divider(height: 1),
            _buildActionTile(
              Icons.delete_outline,
              'Sil',
              () => _deleteFile(context, viewModel, file), // Tekil silme
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  /// "Yeni Klasör" oluşturma diyalogunu gösterir
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

  /// Silme onayı diyalogu
  Future<bool?> _showDeleteConfirmation(BuildContext context, {int count = 1}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(count > 1 ? '$count Öğeyi Sil' : 'Dosyayı Sil'),
        content: Text(
          count > 1
              ? 'Seçili $count öğeyi sunucudan kalıcı olarak silmek istediğinizden emin misiniz?'
              : 'Bu dosyayı sunucudan kalıcı olarak silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
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
    // Controller'ı klasörün mevcut adıyla doldur
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
                  // "Beyin"deki renameFolder fonksiyonunu çağır
                  viewModel.renameFolder(folder, newName);
                } else {
                  Navigator.pop(context); // Değişiklik yoksa kapat
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
        // ViewModel'den tüm klasör listesini al
        final allFolders = viewModel.allFolders;
        // Taşınacak öğelerin (dosya veya klasör) içinde bulunduğu klasörü
        // ve kendilerini listeden çıkar (kendi içine taşıyamazsın)
        final selectableFolders = allFolders.where((folder) {
          // Klasörün kendisini listeden çıkar
          if (viewModel.selectedFolders.contains(folder)) return false;
          // Ana Dizini (ID: 0) her zaman göster
          if (folder.folderId == 0) return true;
          // Öğelerin zaten içinde olduğu klasörü gösterme
          if (folder.folderId == viewModel.currentFolderId) return false;

          return true;
        }).toList();

        // Ana Dizini (ID: 0) manuel olarak ekle (eğer veritabanından gelmiyorsa)
        if (!selectableFolders.any((f) => f.folderId == 0)) {
          selectableFolders.insert(
            0,
            FolderItem(folderId: 0, folderName: "Ana Dizin", parentId: -1),
          );
        }

        return AlertDialog(
          title: const Text('Taşınacak Klasörü Seçin'),
          content: Container(
            width: double.maxFinite,
            // Klasör listesi çok uzun olabilir, kaydırılabilir yap
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: selectableFolders.length,
              itemBuilder: (context, index) {
                final folder = selectableFolders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(folder.folderName),
                  onTap: () {
                    // Tıklandığında taşıma işlemini başlat
                    Navigator.pop(dialogContext); // Diyalogu kapat
                    viewModel.moveSelectedItems(
                      folder.folderId,
                    ); // "Beyin"deki fonk. çağır
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
        // "dosya.pdf" -> "dosya"
        nameWithoutExtension = file.fileName.substring(0, dotIndex);
        // "dosya.pdf" -> ".pdf" (Nokta dahil)
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
              // Uzantıyı ipucu olarak göster
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
                  // "Beyin"deki renameFile fonksiyonunu çağır (Uzantıyı ViewModel ekler)
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

  // --- 7. ALT SEVİYE EYLEMLER (Servisleri çağıranlar) ---

  /// "Beyin"deki tekil silme fonksiyonunu onay alarak çağırır
  Future<void> _deleteFile(
    BuildContext context,
    StorageViewModel viewModel,
    FileItem file,
  ) async {
    final bool? confirmed = await _showDeleteConfirmation(context);
    if (confirmed != true) return;
    viewModel.toggleFileSelection(file); // Önce seç
    await viewModel.deleteSelected(); // Sonra seçilileri sil
    // SnackBar kaldırıldı, ViewModel'in durum çubuğu halledecek
  }

  /// "Beyin"deki toplu silme fonksiyonunu onay alarak çağırır
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

    await viewModel.deleteSelected();
    // SnackBar kaldırıldı, ViewModel'in durum çubuğu halledecek
  }

  /// Toplu indirme (İndirme işlemleri SnackBar kullanmaya devam ediyor)
  Future<void> _downloadSelectedFiles(
    BuildContext context,
    StorageViewModel viewModel,
  ) async {
    int successCount = 0;
    int errorCount = 0;
    final filesToDownload = viewModel.selectedFiles.toList();
    // (Klasör indirme desteklenmiyor, sadece dosyalar)

    if (filesToDownload.isEmpty) {
      viewModel.clearSelection(); // Sadece klasör seçildiyse seçimi temizle
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

  /// Tekil indirme
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

  /// Dosya görüntüleyici yönlendiricisi
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
    // Tarih ve etiketi seç
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

  // --- 8. YARDIMCI METODLAR (Formatlama, İkonlar, Renkler) ---

  /// ✅ YENİ: Tarih gruplaması için eklendi (Eski koddan geri alındı)
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

  /*
  Widget _buildSyncStatus(String syncStatus) {
    final statusColor = _getStatusColor(syncStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: statusColor.withAlpha((255 * 0.1).round()),
      child: Row(
        children: [
          _getStatusIcon(syncStatus),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              syncStatus,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
*/
  Color _getStatusColor(String syncStatus) {
    if (syncStatus.contains('Hata')) return Colors.red;
    if (syncStatus.contains('Başarı') || syncStatus.contains('güncel'))
      return Colors.green;
    return Colors.blue;
  }

  Widget _getStatusIcon(String syncStatus) {
    if (syncStatus.contains('...') || syncStatus.contains('Senkronize')) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (syncStatus.contains('Başarı') || syncStatus.contains('güncel')) {
      return const Icon(Icons.check_circle, size: 16, color: Colors.green);
    }
    if (syncStatus.contains('Hata')) {
      return const Icon(Icons.error, size: 16, color: Colors.red);
    }
    return const Icon(Icons.info, size: 16, color: Colors.blue);
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

      if (difference.inDays == 0) {
        return 'Bugün ${DateFormat('HH:mm').format(date)}';
      }
      if (difference.inDays == 1) {
        return 'Dün ${DateFormat('HH:mm').format(date)}';
      }
      if (difference.inDays < 7) return '${difference.inDays} gün önce';
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
