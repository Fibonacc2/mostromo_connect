// lib/features/storage/viewmodels/storage_view_model.dart
// lib/features/storage/viewmodels/storage_view_model.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mostromo_connect/features/storage/viewmodels/workspace_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shared_core/models/folder_model.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/services/sync_service.dart';
import 'package:shared_core/services/local_storage_service.dart';

// API BASE URL'i global veya servisten alamıyorsak diye güvenli bir tanım (Eğer başka yerde tanımlıysa burayı silebilirsin)
const String API_BASE_URL = "https://mostromo.com/connect/";

class UploadItem {
  final XFile file;
  final int targetFolderId;
  final String targetFolderName;
  final bool isFolder;
  final String relativePathForTree;

  UploadItem({
    required this.file,
    required this.targetFolderId,
    required this.targetFolderName,
    this.isFolder = false,
    this.relativePathForTree = '',
  });
}

enum DownloadStatus { downloading, paused, completed, error }

enum SortType { name, date, size }

class DownloadItem {
  final String id;
  final String fileName;
  final String url;
  final String savePath;
  CancelToken? cancelToken;
  double progress;
  int downloadedBytes;
  int totalBytes;
  DownloadStatus status;

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.url,
    required this.savePath,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.downloading,
  });
}

class StorageViewModel extends ChangeNotifier {
  List<FolderItem> _allFolders = [];
  List<FileItem> _allFiles = [];
  final List<UploadItem> _pendingUploads = [];
  final List<WorkspaceItem> _workspaces = [];

  dynamic _activeItem;
  bool _isInfoPanelOpen = false;
  String _searchQuery = '';

  bool _isLoading = true;
  String _syncStatus = '';

  final List<int> _navigationStack = [0];
  final List<int> _forwardStack = [];

  final Set<FolderItem> _selectedFolders = {};
  final Set<FileItem> _selectedFiles = {};

  StreamSubscription<String>? _syncSubscription;
  Timer? _statusTimer;

  bool _isTrashMode = false;
  bool get isTrashMode => _isTrashMode;

  bool _isListView = false;
  bool get isListView => _isListView;

  SortType _sortType = SortType.date;
  bool _sortAscending = false;

  SortType get sortType => _sortType;
  bool get sortAscending => _sortAscending;

  bool get canGoBack => _navigationStack.length > 1;
  bool get canGoForward => _forwardStack.isNotEmpty;
  bool get isAtRoot => !canGoBack;

  void setTrashMode(bool value) {
    if (_isTrashMode != value) {
      _isTrashMode = value;
      _navigationStack.clear();
      _navigationStack.add(0);
      _forwardStack.clear();
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _isListView = !_isListView;
    notifyListeners();
  }

  void setSortType(SortType type) {
    if (_sortType == type) {
      _sortAscending = !_sortAscending;
    } else {
      _sortType = type;
      _sortAscending = type == SortType.name ? true : false;
    }
    notifyListeners();
  }

  List<FolderItem> get breadcrumbs {
    List<FolderItem> path = [
      FolderItem(folderId: 0, folderName: "Dosyalarım", parentId: -1),
    ];
    for (int i = 1; i < _navigationStack.length; i++) {
      final id = _navigationStack[i];
      try {
        final folder = _allFolders.firstWhere((f) => f.folderId == id);
        path.add(folder);
      } catch (e) {}
    }
    return path;
  }

  void navigateToBreadcrumbIndex(int index) {
    if (index >= 0 && index < _navigationStack.length - 1) {
      final removed = _navigationStack.sublist(index + 1);
      _forwardStack.clear();
      _forwardStack.addAll(removed.reversed);

      _navigationStack.removeRange(index + 1, _navigationStack.length);
      _searchQuery = '';
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  void navigateToFolder(FolderItem folder) {
    _navigationStack.add(folder.folderId);
    _forwardStack.clear();
    _searchQuery = '';
    clearSelection();
    closeInfoPanel();
    notifyListeners();
  }

  void goBack() {
    if (canGoBack) {
      _forwardStack.add(_navigationStack.removeLast());
      _searchQuery = '';
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  void goForward() {
    if (canGoForward) {
      _navigationStack.add(_forwardStack.removeLast());
      _searchQuery = '';
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  List<FolderItem> get allFolders => _allFolders;
  List<FileItem> get allFiles => _allFiles;
  List<UploadItem> get pendingUploads => _pendingUploads;
  List<WorkspaceItem> get workspaces => _workspaces;
  bool get isLoading => _isLoading;
  String get syncStatus => _syncStatus;
  int get currentFolderId => _navigationStack.last;
  dynamic get activeItem => _activeItem;
  bool get isInfoPanelOpen => _isInfoPanelOpen;
  String get searchQuery => _searchQuery;

  String get currentFolderName {
    if (currentFolderId == 0) return "Dosyalarım";
    try {
      return _allFolders
          .firstWhere((f) => f.folderId == currentFolderId)
          .folderName;
    } catch (e) {
      return "Klasör";
    }
  }

  bool get isSelectionMode =>
      _selectedFolders.isNotEmpty || _selectedFiles.isNotEmpty;

  void _sortFolders(List<FolderItem> folders) {
    folders.sort((a, b) {
      int result = a.folderName.toLowerCase().compareTo(
        b.folderName.toLowerCase(),
      );
      return (_sortType == SortType.name && !_sortAscending) ? -result : result;
    });
  }

  void _sortFiles(List<FileItem> files) {
    files.sort((a, b) {
      int result = 0;
      switch (_sortType) {
        case SortType.name:
          result = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
          break;
        case SortType.size:
          result = a.fileSize.compareTo(b.fileSize);
          break;
        case SortType.date:
          final dateA = (a.lastUpdated != null && a.lastUpdated!.isNotEmpty)
              ? DateTime.parse(a.lastUpdated!)
              : DateTime.tryParse(a.createdAt) ?? DateTime(2000);
          final dateB = (b.lastUpdated != null && b.lastUpdated!.isNotEmpty)
              ? DateTime.parse(b.lastUpdated!)
              : DateTime.tryParse(b.createdAt) ?? DateTime(2000);
          result = dateA.compareTo(dateB);
          break;
      }
      return _sortAscending ? result : -result;
    });
  }

  List<FolderItem> get activeFolders {
    var folders = _allFolders
        .where((f) => !f.isTrashed && f.parentId == currentFolderId)
        .toList();
    if (_searchQuery.isNotEmpty) {
      folders = folders
          .where(
            (f) =>
                f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFolders(folders);
    return folders;
  }

  List<FileItem> get activeFiles {
    var files = _allFiles
        .where((f) => !f.isTrashed && f.folderId == currentFolderId)
        .toList();
    if (_searchQuery.isNotEmpty) {
      files = files
          .where(
            (f) =>
                f.fileName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFiles(files);
    return files;
  }

  List<FolderItem> get trashFolders {
    var folders = _allFolders.where((f) => f.isTrashed).toList();
    if (_searchQuery.isNotEmpty) {
      folders = folders
          .where(
            (f) =>
                f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFolders(folders);
    return folders;
  }

  List<FileItem> get trashFiles {
    var files = _allFiles.where((f) => f.isTrashed).toList();
    if (_searchQuery.isNotEmpty) {
      files = files
          .where(
            (f) =>
                f.fileName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFiles(files);
    return files;
  }

  Set<FolderItem> get selectedFolders => _selectedFolders;
  Set<FileItem> get selectedFiles => _selectedFiles;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectItem(dynamic item) {
    _activeItem = item;
    _isInfoPanelOpen = true;
    notifyListeners();
  }

  void closeInfoPanel() {
    _isInfoPanelOpen = false;
    _activeItem = null;
    notifyListeners();
  }

  StorageViewModel() {
    fetchData();
    _syncSubscription = SyncService.syncStatusStream.listen(_updateSyncStatus);
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _updateSyncStatus(String status) {
    _syncStatus = status;
    notifyListeners();

    if (status.contains('...') ||
        status.contains('Senkronize') ||
        status.contains('Yükleniyor')) {
      _statusTimer?.cancel();
      return;
    }

    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 4), () {
      _syncStatus = '';
      notifyListeners();
    });
  }

  Future<void> fetchWorkspaces() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null || userId == 0) return;

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=get",
        ),
        body: {'user_id': userId.toString()},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _workspaces.clear();
          _workspaces.addAll(
            decoded
                .map(
                  (json) =>
                      WorkspaceItem.fromJson(json as Map<String, dynamic>),
                )
                .toList(),
          );
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<bool> createWorkspace({
    required String name,
    required String localPath,
    required int remoteFolderId,
    required String remoteFolderName,
    bool autoSync = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    final normalizedPath = localPath.replaceAll('\\', '/');
    bool isSuccess = false;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null || userId == 0) return false;

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=create",
        ),
        body: {
          'name': name,
          'local_path': normalizedPath,
          'remote_folder_id': remoteFolderId.toString(),
          'remote_folder_name': remoteFolderName,
          'auto_sync': autoSync ? '1' : '0',
          'user_id': userId.toString(),
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await fetchWorkspaces();
          _updateSyncStatus("💼 '$name' çalışma alanı bağlandı.");
          isSuccess = true;
        } else {
          _updateSyncStatus("❌ Hata: ${data['message']}");
        }
      }
    } catch (e) {
      _updateSyncStatus("❌ Bağlantı hatası.");
    }
    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null || userId == 0) return;

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=delete",
        ),
        body: {'id': workspaceId, 'user_id': userId.toString()},
      );
      if (response.statusCode == 200) {
        _workspaces.removeWhere((w) => w.id == workspaceId);
        _updateSyncStatus("🗑️ Çalışma alanı silindi.");
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> toggleWorkspaceSync(String workspaceId, bool newValue) async {
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index == -1) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null || userId == 0) return;

    _workspaces[index] = _workspaces[index].copyWith(autoSync: newValue);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=toggle_sync",
        ),
        body: {
          'id': workspaceId,
          'auto_sync': newValue ? '1' : '0',
          'user_id': userId.toString(),
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          _updateSyncStatus("✅ Senkronizasyon güncellendi.");
          return;
        }
      }
    } catch (e) {}

    _workspaces[index] = _workspaces[index].copyWith(autoSync: !newValue);
    _updateSyncStatus("❌ Kaydedilemedi.");
    notifyListeners();
  }

  WorkspaceItem? findWorkspaceByPath(String filePath) {
    final normalizedFilePath = filePath.replaceAll('\\', '/').toLowerCase();
    for (var workspace in _workspaces) {
      if (normalizedFilePath.startsWith(workspace.localPath.toLowerCase()))
        return workspace;
    }
    return null;
  }

  void addProgrammaticUpload({
    required XFile file,
    required int targetFolderId,
    required String targetFolderName,
    bool isFolder = false,
    String relativePathForTree = '',
  }) {
    if (!_pendingUploads.any((item) => item.file.path == file.path)) {
      _pendingUploads.add(
        UploadItem(
          file: file,
          targetFolderId: targetFolderId,
          targetFolderName: targetFolderName,
          isFolder: isFolder,
          relativePathForTree: relativePathForTree,
        ),
      );
      notifyListeners();
    }
  }

  void removePendingUpload(int index) {
    _pendingUploads.removeAt(index);
    notifyListeners();
  }

  void clearPendingUploads() {
    _pendingUploads.clear();
    notifyListeners();
  }

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _currentlyUploadingName = '';

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get currentlyUploadingName => _currentlyUploadingName;

  Future<void> startUpload() async {
    if (_isUploading) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return;

    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    Map<String, double> progressMap = {};

    while (_pendingUploads.isNotEmpty) {
      final List<UploadItem> allItems = List.from(_pendingUploads);

      void updateOverallProgress() {
        double totalProgress = 0.0;
        for (var item in allItems)
          totalProgress += progressMap[item.file.path] ?? 0.0;
        _uploadProgress = (totalProgress / allItems.length).clamp(0.0, 1.0);
        notifyListeners();
      }

      final folderItems = allItems.where((item) => item.isFolder).toList();
      folderItems.sort(
        (a, b) => a.relativePathForTree
            .split('/')
            .length
            .compareTo(b.relativePathForTree.split('/').length),
      );

      for (var item in folderItems) {
        await resolveOrCreateFolderTree(
          item.relativePathForTree,
          item.targetFolderId,
        );
        progressMap[item.file.path] = 1.0;
        _pendingUploads.remove(item);
        updateOverallProgress();
      }

      final fileItems = allItems.where((item) => !item.isFolder).toList();
      const int maxConcurrent = 3;

      while (fileItems.isNotEmpty) {
        final batch = fileItems.take(maxConcurrent).toList();
        for (var item in batch) fileItems.remove(item);

        _currentlyUploadingName = batch
            .map((e) => e.file.name.split('/').last)
            .join(', ');
        notifyListeners();

        List<Future<void>> uploadTasks = [];

        for (var item in batch) {
          int finalTargetFolderId = await resolveOrCreateFolderTree(
            item.relativePathForTree,
            item.targetFolderId,
          );

          uploadTasks.add(
            SyncService.uploadFileInChunks(
              file: File(item.file.path),
              folderId: finalTargetFolderId,
              userId: userId, // Düzeltme
              onProgress: (progress) {
                progressMap[item.file.path] = progress;
                updateOverallProgress();
              },
            ).then((success) {
              progressMap[item.file.path] = 1.0;
              _pendingUploads.remove(item);
              updateOverallProgress();
            }),
          );
        }
        await Future.wait(uploadTasks);
      }
    }

    _isUploading = false;
    _uploadProgress = 1.0;
    _currentlyUploadingName = '';
    await fetchData();
    notifyListeners();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _syncStatus = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    if (userId == 0) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final localData = await LocalStorageService.loadLocalData();
      if (localData.folders.isNotEmpty || localData.files.isNotEmpty) {
        _allFolders = localData.folders;
        _allFiles = localData.files;
        notifyListeners();
      }
    } catch (e) {}

    await fetchWorkspaces();
    final result = await SyncService.syncFiles(userId: userId); // Düzeltme

    if (result.success) {
      _allFolders = result.folders;
      _allFiles = result.files;
    } else {
      _updateSyncStatus("❌ ${result.message}");
      debugPrint("🔴 EŞİTLEME HATASI: ${result.message}");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createFolder(String folderName) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final newFolder = await SyncService.createFolder(
      folderName,
      currentFolderId,
      userId: userId,
    );
    if (newFolder != null) {
      _allFolders.add(newFolder);
      _updateSyncStatus("✅ '${newFolder.folderName}' oluşturuldu.");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> moveToTrash() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final List<FolderItem> foldersToDelete = _selectedFolders.toList();
    final List<FileItem> filesToDelete = _selectedFiles.toList();

    if (await SyncService.trashItems(
      folders: foldersToDelete,
      files: filesToDelete,
      userId: userId,
    )) {
      await fetchData();
      _updateSyncStatus('🗑️ Öğeler Geri Dönüşüm Kutusuna taşındı.');
    } else {
      _updateSyncStatus('❌ Öğeler silinemedi.');
    }

    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePermanently() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final List<FolderItem> foldersToDelete = _selectedFolders.toList();
    final List<FileItem> filesToDelete = _selectedFiles.toList();
    int successFileCount = 0;
    int successFolderCount = 0;

    for (var file in filesToDelete) {
      if (await SyncService.deleteFile(file, userId: userId)) {
        successFileCount++;
        _allFiles.remove(file);
      }
    }

    for (var folder in foldersToDelete) {
      if (await SyncService.deleteFolder(folder, userId: userId) == null) {
        successFolderCount++;
        _allFolders.remove(folder);
      }
    }

    _updateSyncStatus(
      '✅ $successFolderCount klasör, $successFileCount dosya kalıcı olarak silindi.',
    );
    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> restoreSelected() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    if (await SyncService.restoreItems(
      folders: _selectedFolders.toList(),
      files: _selectedFiles.toList(),
      userId: userId,
    )) {
      await fetchData();
      _updateSyncStatus('✅ Öğeler başarıyla geri yüklendi.');
    } else {
      _updateSyncStatus('❌ Öğeler geri yüklenemedi.');
    }

    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameFolder(FolderItem folder, String newName) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final updatedFolder = await SyncService.renameFolder(
      folder,
      newName,
      userId: userId,
    );
    if (updatedFolder != null) {
      final index = _allFolders.indexWhere(
        (f) => f.folderId == folder.folderId,
      );
      if (index != -1) _allFolders[index] = updatedFolder;
      _updateSyncStatus("✅ Klasör adı güncellendi.");
      clearSelection();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> moveSelectedItems(int targetFolderId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final errorMessage = await SyncService.moveItems(
      folders: _selectedFolders.toList(),
      files: _selectedFiles.toList(),
      targetFolderId: targetFolderId,
      userId: userId,
    );
    if (errorMessage == null) {
      fetchData();
      clearSelection();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameFile(FileItem file, String newName) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    String oldExtension = file.fileName.contains('.')
        ? file.fileName.split('.').last
        : "";
    String finalNewName = newName.trim();
    if (oldExtension.isNotEmpty && !finalNewName.endsWith('.$oldExtension'))
      finalNewName = '$finalNewName.$oldExtension';

    final updatedFile = await SyncService.renameFile(
      file,
      finalNewName,
      userId: userId,
    );
    if (updatedFile != null) {
      final index = _allFiles.indexWhere((f) => f.fileUrl == file.fileUrl);
      if (index != -1)
        _allFiles[index] = updatedFile.copyWith(
          lastUpdated: DateTime.now().toIso8601String(),
        );
      _updateSyncStatus("✅ Dosya adı güncellendi.");
    }
    _isLoading = false;
    notifyListeners();
  }

  void toggleFileSelection(FileItem file) {
    if (_selectedFiles.contains(file))
      _selectedFiles.remove(file);
    else
      _selectedFiles.add(file);
    notifyListeners();
  }

  void toggleFolderSelection(FolderItem folder) {
    if (_selectedFolders.contains(folder))
      _selectedFolders.remove(folder);
    else
      _selectedFolders.add(folder);
    notifyListeners();
  }

  void selectAll({bool isTrash = false}) {
    if (isTrash) {
      _selectedFolders.addAll(trashFolders);
      _selectedFiles.addAll(trashFiles);
    } else {
      _selectedFolders.addAll(activeFolders);
      _selectedFiles.addAll(activeFiles);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedFolders.clear();
    _selectedFiles.clear();
    notifyListeners();
  }

  void updateMarqueeSelection(
    List<dynamic> intersectingItems, {
    required Set<dynamic> preDragSelection,
  }) {
    _selectedFolders.clear();
    _selectedFiles.clear();

    for (var item in preDragSelection) {
      if (item is FolderItem) _selectedFolders.add(item);
      if (item is FileItem) _selectedFiles.add(item);
    }

    for (var item in intersectingItems) {
      if (item is FolderItem) _selectedFolders.add(item);
      if (item is FileItem) _selectedFiles.add(item);
    }
    notifyListeners();
  }

  Future<int> resolveOrCreateFolderTree(
    String relativePath,
    int rootFolderId,
  ) async {
    if (relativePath.isEmpty || relativePath == '/' || relativePath == '.')
      return rootFolderId;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final parts = relativePath
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    int currentParentId = rootFolderId;

    for (var part in parts) {
      final existingFolders = _allFolders.where(
        (f) => f.parentId == currentParentId && f.folderName == part,
      );
      if (existingFolders.isNotEmpty) {
        currentParentId = existingFolders.first.folderId;
      } else {
        final newFolder = await SyncService.createFolder(
          part,
          currentParentId,
          userId: userId, // Düzeltme
        );
        if (newFolder != null) {
          _allFolders.add(newFolder);
          currentParentId = newFolder.folderId;
          notifyListeners();
        } else {
          return currentParentId;
        }
      }
    }
    return currentParentId;
  }

  Future<void> handlePaths(
    List<String> paths, {
    int? customTargetFolderId,
  }) async {
    final targetFolderId = customTargetFolderId ?? currentFolderId;
    _isLoading = true;
    notifyListeners();
    int addedCount = 0;

    for (String path in paths) {
      try {
        final normalizedPath = path.replaceAll('\\', '/');
        final entityType = await FileSystemEntity.type(normalizedPath);

        if (entityType == FileSystemEntityType.directory) {
          final dir = Directory(normalizedPath);
          final parentPath = dir.parent.path.replaceAll('\\', '/');
          bool isEmpty = true;

          await for (var entity
              in dir
                  .list(recursive: true, followLinks: false)
                  .handleError((e) {})) {
            isEmpty = false;
            final entityNormPath = entity.path.replaceAll('\\', '/');
            String relativePath = entityNormPath.replaceFirst(
              '$parentPath/',
              '',
            );

            if (entity is File) {
              String relativeDir = relativePath.contains('/')
                  ? relativePath.substring(0, relativePath.lastIndexOf('/'))
                  : '';
              addProgrammaticUpload(
                file: XFile(entityNormPath),
                targetFolderId: targetFolderId,
                targetFolderName: relativeDir.isEmpty
                    ? currentFolderName
                    : relativeDir,
                isFolder: false,
                relativePathForTree: relativeDir,
              );
              addedCount++;
            } else if (entity is Directory) {
              bool isSubEmpty = true;
              try {
                if (entity.listSync().isNotEmpty) isSubEmpty = false;
              } catch (e) {}
              if (isSubEmpty) {
                addProgrammaticUpload(
                  file: XFile(entityNormPath),
                  targetFolderId: targetFolderId,
                  targetFolderName: relativePath,
                  isFolder: true,
                  relativePathForTree: relativePath,
                );
                addedCount++;
              }
            }
          }

          if (isEmpty) {
            String relativePath = normalizedPath.replaceFirst(
              '$parentPath/',
              '',
            );
            addProgrammaticUpload(
              file: XFile(normalizedPath),
              targetFolderId: targetFolderId,
              targetFolderName: relativePath,
              isFolder: true,
              relativePathForTree: relativePath,
            );
            addedCount++;
          }
        } else if (entityType == FileSystemEntityType.file) {
          addProgrammaticUpload(
            file: XFile(normalizedPath),
            targetFolderId: targetFolderId,
            targetFolderName: currentFolderName,
            isFolder: false,
            relativePathForTree: '',
          );
          addedCount++;
        }
      } catch (e) {}
    }

    if (addedCount == 0)
      _updateSyncStatus("Kuyruğa eklenecek yeni öğe bulunamadı.");
    else
      _updateSyncStatus(
        "⏳ $addedCount öğe kuyruğa eklendi, onayınız bekleniyor.",
      );

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // 📥 KESİNTİSİZ ASENKRON İNDİRME MOTORU
  // =====================================================================
  final List<DownloadItem> _activeDownloads = [];
  List<DownloadItem> get activeDownloads => _activeDownloads;

  Future<void> startDownload(FileItem file) async {
    String url = file.fileUrl;
    if (!url.startsWith('http')) {
      url = "https://mostromo.com/connect/$url";
    }

    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final mostromoDir = Directory('${dir.path}/Mostromo');
    if (!await mostromoDir.exists()) {
      await mostromoDir.create(recursive: true);
    }

    final savePath = '${mostromoDir.path}/${file.fileName}';

    if (_activeDownloads.any((item) => item.id == file.fileUrl)) return;

    final newItem = DownloadItem(
      id: file.fileUrl,
      fileName: file.fileName,
      url: url,
      savePath: savePath,
    );

    _activeDownloads.add(newItem);
    notifyListeners();

    _processDownload(newItem);
  }

  // 🌟 KLASÖR İNDİRME FONKSİYONU
  Future<void> startFolderDownload(FolderItem folder) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return;

    // PHP ZIP motorumuzun adresi
    String url =
        "https://mostromo.com/connect/android/download_folder.php?folder_id=${folder.folderId}&user_id=$userId";

    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final mostromoDir = Directory('${dir.path}/Mostromo');
    if (!await mostromoDir.exists()) {
      await mostromoDir.create(recursive: true);
    }

    // Klasör ZIP olarak inecek
    final savePath = '${mostromoDir.path}/${folder.folderName}.zip';

    if (_activeDownloads.any((item) => item.id == 'folder_${folder.folderId}'))
      return;

    final newItem = DownloadItem(
      id: 'folder_${folder.folderId}',
      fileName: '${folder.folderName}.zip',
      url: url,
      savePath: savePath,
    );

    _activeDownloads.add(newItem);
    notifyListeners();

    _processDownload(newItem);
  }

  Future<void> _processDownload(DownloadItem item) async {
    item.cancelToken = CancelToken();
    item.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final file = File(item.savePath);
      int startByte = 0;

      if (await file.exists()) {
        startByte = await file.length();
      }

      final dio = Dio();

      final options = Options(
        responseType: ResponseType.stream,
        headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : {},
      );

      final response = await dio.get<ResponseBody>(
        item.url,
        cancelToken: item.cancelToken,
        options: options,
      );

      if (item.totalBytes == 0) {
        final contentRange = response.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        if (contentRange != null) {
          item.totalBytes = int.parse(contentRange.split('/').last);
        } else {
          final contentLength = response.headers.value(
            HttpHeaders.contentLengthHeader,
          );
          if (contentLength != null) {
            item.totalBytes = int.parse(contentLength) + startByte;
          }
        }
      }

      if (response.statusCode == 200 && startByte > 0) {
        startByte = 0;
        await file.writeAsBytes([]);
      }

      if (startByte == item.totalBytes && item.totalBytes > 0) {
        item.progress = 1.0;
        item.status = DownloadStatus.completed;
        notifyListeners();
        return;
      }

      final raf = await file.open(mode: FileMode.append);
      final stream = response.data!.stream;

      int downloaded = startByte;
      final stopwatch = Stopwatch()..start();

      await for (var chunk in stream) {
        if (item.cancelToken!.isCancelled) break;

        await raf.writeFrom(chunk);
        downloaded += chunk.length;
        item.downloadedBytes = downloaded;

        if (item.totalBytes > 0) {
          item.progress = downloaded / item.totalBytes;

          if (stopwatch.elapsedMilliseconds > 100 ||
              downloaded == item.totalBytes) {
            notifyListeners();
            stopwatch.reset();
          }
        } else {
          if (stopwatch.elapsedMilliseconds > 100) {
            notifyListeners();
            stopwatch.reset();
          }
        }
      }

      await raf.close();

      if (!item.cancelToken!.isCancelled) {
        item.status = DownloadStatus.completed;
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        item.status = DownloadStatus.paused;
      } else {
        item.status = DownloadStatus.error;
      }
      notifyListeners();
    }
  }

  void pauseDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      _activeDownloads[index].cancelToken?.cancel("Duraklatıldı");
    }
  }

  void resumeDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      _processDownload(_activeDownloads[index]);
    }
  }

  void cancelDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      item.cancelToken?.cancel("İptal Edildi");
      final file = File(item.savePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _activeDownloads.removeAt(index);
      notifyListeners();
    }
  }

  void clearCompletedDownloads() {
    _activeDownloads.removeWhere(
      (item) => item.status == DownloadStatus.completed,
    );
    if (_activeDownloads.isEmpty) notifyListeners();
  }

  // =====================================================================
  // 🔗 DOSYA VE KLASÖR PAYLAŞIM SİSTEMİ
  // =====================================================================
  Future<Map<String, dynamic>?> getShareLinkInfo(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return null;

    final isFolder = item is FolderItem;

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/share_manager.php"),
        body: json.encode({
          'action': 'get',
          'user_id': userId,
          'item_type': isFolder ? 'folder' : 'file',
          'file_url': isFolder
              ? null
              : (item as FileItem).fileUrl.replaceFirst(API_BASE_URL, ''),
          'folder_id': isFolder ? (item as FolderItem).folderId : null,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data;
      }
    } catch (e) {}
    return null;
  }

  Future<Map<String, dynamic>?> generateShareLink(
    dynamic item, {
    String? password,
    int expireHours = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return null;

    final isFolder = item is FolderItem;

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/share_manager.php"),
        body: json.encode({
          'action': 'create',
          'user_id': userId,
          'item_type': isFolder ? 'folder' : 'file',
          'file_url': isFolder
              ? null
              : (item as FileItem).fileUrl.replaceFirst(API_BASE_URL, ''),
          'folder_id': isFolder ? (item as FolderItem).folderId : null,
          'password': password,
          'expire_hours': expireHours,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data;
      }
    } catch (e) {}
    return null;
  }

  Future<bool> revokeShareLink(dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;

    final isFolder = item is FolderItem;

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/share_manager.php"),
        body: json.encode({
          'action': 'revoke',
          'user_id': userId,
          'item_type': isFolder ? 'folder' : 'file',
          'file_url': isFolder
              ? null
              : (item as FileItem).fileUrl.replaceFirst(API_BASE_URL, ''),
          'folder_id': isFolder ? (item as FolderItem).folderId : null,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['success'] == true;
      }
    } catch (e) {}
    return false;
  }

  // 🌟 YENİ EKLENDİ: Tüm Paylaşılan Linkleri Getirme
  Future<List<Map<String, dynamic>>> fetchSharedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    if (userId == 0) return [];

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/share_manager.php"),
        body: json.encode({'action': 'list', 'user_id': userId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['links'] ?? []);
        }
      }
    } catch (e) {}
    return [];
  }
}

/*
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mostromo_connect/features/storage/viewmodels/workspace_model.dart';

import 'package:shared_core/models/folder_model.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/services/sync_service.dart';
import 'package:shared_core/services/local_storage_service.dart';

class UploadItem {
  final XFile file;
  final int targetFolderId;
  final String targetFolderName;
  final bool isFolder;
  final String relativePathForTree;

  UploadItem({
    required this.file,
    required this.targetFolderId,
    required this.targetFolderName,
    this.isFolder = false,
    this.relativePathForTree = '',
  });
}

enum DownloadStatus { downloading, paused, completed, error }

// 🌟 YENİ: Sıralama Türleri
enum SortType { name, date, size }

class DownloadItem {
  final String id;
  final String fileName;
  final String url;
  final String savePath;
  CancelToken? cancelToken;
  double progress;
  int downloadedBytes;
  int totalBytes;
  DownloadStatus status;

  DownloadItem({
    required this.id,
    required this.fileName,
    required this.url,
    required this.savePath,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.downloading,
  });
}

class StorageViewModel extends ChangeNotifier {
  List<FolderItem> _allFolders = [];
  List<FileItem> _allFiles = [];
  final List<UploadItem> _pendingUploads = [];
  final List<WorkspaceItem> _workspaces = [];

  dynamic _activeItem;
  bool _isInfoPanelOpen = false;
  String _searchQuery = '';

  bool _isLoading = true;
  String _syncStatus = '';
  final List<int> _navigationStack = [0];
  final Set<FolderItem> _selectedFolders = {};
  final Set<FileItem> _selectedFiles = {};

  StreamSubscription<String>? _syncSubscription;
  Timer? _statusTimer;

  bool _isTrashMode = false;
  bool get isTrashMode => _isTrashMode;

  bool _isListView = false;
  bool get isListView => _isListView;

  // 🌟 YENİ: Sıralama Durumları
  SortType _sortType = SortType.date; // Varsayılan olarak en yeniler
  bool _sortAscending = false;

  SortType get sortType => _sortType;
  bool get sortAscending => _sortAscending;

  void setTrashMode(bool value) {
    if (_isTrashMode != value) {
      _isTrashMode = value;
      _navigationStack.clear();
      _navigationStack.add(0);
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _isListView = !_isListView;
    notifyListeners();
  }

  // 🌟 YENİ: Sıralama Değiştirici
  void setSortType(SortType type) {
    if (_sortType == type) {
      // Aynı türe tıklandıysa yönünü (Artan/Azalan) değiştir
      _sortAscending = !_sortAscending;
    } else {
      _sortType = type;
      // İsime göreyse A-Z (Artan), Tarihe göreyse Yeni (Azalan) başlasın
      _sortAscending = type == SortType.name ? true : false;
    }
    notifyListeners();
  }

  // 🌟 YENİ: Breadcrumbs (Yol Haritası) Hesaplayıcısı
  List<FolderItem> get breadcrumbs {
    List<FolderItem> path = [
      FolderItem(folderId: 0, folderName: "Dosyalarım", parentId: -1),
    ];
    for (int i = 1; i < _navigationStack.length; i++) {
      final id = _navigationStack[i];
      try {
        final folder = _allFolders.firstWhere((f) => f.folderId == id);
        path.add(folder);
      } catch (e) {
        // Hata olursa es geç
      }
    }
    return path;
  }

  void navigateToBreadcrumbIndex(int index) {
    if (index >= 0 && index < _navigationStack.length - 1) {
      _navigationStack.removeRange(index + 1, _navigationStack.length);
      _searchQuery = '';
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  List<FolderItem> get allFolders => _allFolders;
  List<FileItem> get allFiles => _allFiles;
  List<UploadItem> get pendingUploads => _pendingUploads;
  List<WorkspaceItem> get workspaces => _workspaces;
  bool get isLoading => _isLoading;
  String get syncStatus => _syncStatus;
  int get currentFolderId => _navigationStack.last;
  dynamic get activeItem => _activeItem;
  bool get isInfoPanelOpen => _isInfoPanelOpen;
  String get searchQuery => _searchQuery;

  String get currentFolderName {
    if (currentFolderId == 0) return "Dosyalarım";
    try {
      return _allFolders
          .firstWhere((f) => f.folderId == currentFolderId)
          .folderName;
    } catch (e) {
      return "Klasör";
    }
  }

  bool get isAtRoot => _navigationStack.length == 1;
  bool get isSelectionMode =>
      _selectedFolders.isNotEmpty || _selectedFiles.isNotEmpty;

  // =====================================================================
  // 🌟 BAĞIMSIZ LİSTELER VE SIRALAMA MOTORU (SORTING)
  // =====================================================================

  void _sortFolders(List<FolderItem> folders) {
    folders.sort((a, b) {
      // Klasörler genellikle A-Z isme göre sıralanır
      int result = a.folderName.toLowerCase().compareTo(
        b.folderName.toLowerCase(),
      );
      return (_sortType == SortType.name && !_sortAscending) ? -result : result;
    });
  }

  void _sortFiles(List<FileItem> files) {
    files.sort((a, b) {
      int result = 0;
      switch (_sortType) {
        case SortType.name:
          result = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
          break;
        case SortType.size:
          result = a.fileSize.compareTo(b.fileSize);
          break;
        case SortType.date:
          final dateA = (a.lastUpdated != null && a.lastUpdated!.isNotEmpty)
              ? DateTime.parse(a.lastUpdated!)
              : DateTime.tryParse(a.createdAt) ?? DateTime(2000);
          final dateB = (b.lastUpdated != null && b.lastUpdated!.isNotEmpty)
              ? DateTime.parse(b.lastUpdated!)
              : DateTime.tryParse(b.createdAt) ?? DateTime(2000);
          result = dateA.compareTo(dateB);
          break;
      }
      return _sortAscending ? result : -result;
    });
  }

  List<FolderItem> get activeFolders {
    var folders = _allFolders
        .where((f) => !f.isTrashed && f.parentId == currentFolderId)
        .toList();
    if (_searchQuery.isNotEmpty) {
      folders = folders
          .where(
            (f) =>
                f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFolders(folders);
    return folders;
  }

  List<FileItem> get activeFiles {
    var files = _allFiles
        .where((f) => !f.isTrashed && f.folderId == currentFolderId)
        .toList();
    if (_searchQuery.isNotEmpty) {
      files = files
          .where(
            (f) =>
                f.fileName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFiles(files);
    return files;
  }

  List<FolderItem> get trashFolders {
    var folders = _allFolders.where((f) => f.isTrashed).toList();
    if (_searchQuery.isNotEmpty) {
      folders = folders
          .where(
            (f) =>
                f.folderName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFolders(folders);
    return folders;
  }

  List<FileItem> get trashFiles {
    var files = _allFiles.where((f) => f.isTrashed).toList();
    if (_searchQuery.isNotEmpty) {
      files = files
          .where(
            (f) =>
                f.fileName.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _sortFiles(files);
    return files;
  }

  Set<FolderItem> get selectedFolders => _selectedFolders;
  Set<FileItem> get selectedFiles => _selectedFiles;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectItem(dynamic item) {
    _activeItem = item;
    _isInfoPanelOpen = true;
    notifyListeners();
  }

  void closeInfoPanel() {
    _isInfoPanelOpen = false;
    _activeItem = null;
    notifyListeners();
  }

  StorageViewModel() {
    fetchData();
    _syncSubscription = SyncService.syncStatusStream.listen(_updateSyncStatus);
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _updateSyncStatus(String status) {
    _syncStatus = status;
    notifyListeners();

    if (status.contains('...') ||
        status.contains('Senkronize') ||
        status.contains('Yükleniyor')) {
      _statusTimer?.cancel();
      return;
    }

    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 4), () {
      _syncStatus = '';
      notifyListeners();
    });
  }

  Future<void> fetchWorkspaces() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=get",
        ),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _workspaces.clear();
          _workspaces.addAll(
            decoded
                .map(
                  (json) =>
                      WorkspaceItem.fromJson(json as Map<String, dynamic>),
                )
                .toList(),
          );
          notifyListeners();
        }
      }
    } catch (e) {}
  }

  Future<bool> createWorkspace({
    required String name,
    required String localPath,
    required int remoteFolderId,
    required String remoteFolderName,
    bool autoSync = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    final normalizedPath = localPath.replaceAll('\\', '/');
    bool isSuccess = false;

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=create",
        ),
        body: {
          'name': name,
          'local_path': normalizedPath,
          'remote_folder_id': remoteFolderId.toString(),
          'remote_folder_name': remoteFolderName,
          'auto_sync': autoSync ? '1' : '0',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await fetchWorkspaces();
          _updateSyncStatus("💼 '$name' çalışma alanı bağlandı.");
          isSuccess = true;
        } else {
          _updateSyncStatus("❌ Hata: ${data['message']}");
        }
      }
    } catch (e) {
      _updateSyncStatus("❌ Bağlantı hatası.");
    }
    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=delete",
        ),
        body: {'id': workspaceId},
      );
      if (response.statusCode == 200) {
        _workspaces.removeWhere((w) => w.id == workspaceId);
        _updateSyncStatus("🗑️ Çalışma alanı silindi.");
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> toggleWorkspaceSync(String workspaceId, bool newValue) async {
    final index = _workspaces.indexWhere((w) => w.id == workspaceId);
    if (index == -1) return;

    _workspaces[index] = _workspaces[index].copyWith(autoSync: newValue);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(
          "https://mostromo.com/connect/android/workspaces.php?action=toggle_sync",
        ),
        body: {'id': workspaceId, 'auto_sync': newValue ? '1' : '0'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          _updateSyncStatus("✅ Senkronizasyon güncellendi.");
          return;
        }
      }
    } catch (e) {}

    _workspaces[index] = _workspaces[index].copyWith(autoSync: !newValue);
    _updateSyncStatus("❌ Kaydedilemedi.");
    notifyListeners();
  }

  WorkspaceItem? findWorkspaceByPath(String filePath) {
    final normalizedFilePath = filePath.replaceAll('\\', '/').toLowerCase();
    for (var workspace in _workspaces) {
      if (normalizedFilePath.startsWith(workspace.localPath.toLowerCase()))
        return workspace;
    }
    return null;
  }

  void addProgrammaticUpload({
    required XFile file,
    required int targetFolderId,
    required String targetFolderName,
    bool isFolder = false,
    String relativePathForTree = '',
  }) {
    if (!_pendingUploads.any((item) => item.file.path == file.path)) {
      _pendingUploads.add(
        UploadItem(
          file: file,
          targetFolderId: targetFolderId,
          targetFolderName: targetFolderName,
          isFolder: isFolder,
          relativePathForTree: relativePathForTree,
        ),
      );
      notifyListeners();
    }
  }

  void removePendingUpload(int index) {
    _pendingUploads.removeAt(index);
    notifyListeners();
  }

  void clearPendingUploads() {
    _pendingUploads.clear();
    notifyListeners();
  }

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _currentlyUploadingName = '';

  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get currentlyUploadingName => _currentlyUploadingName;

  Future<void> startUpload() async {
    if (_isUploading) return;

    _isUploading = true;
    _uploadProgress = 0.0;
    notifyListeners();

    Map<String, double> progressMap = {};

    while (_pendingUploads.isNotEmpty) {
      final List<UploadItem> allItems = List.from(_pendingUploads);

      void updateOverallProgress() {
        double totalProgress = 0.0;
        for (var item in allItems)
          totalProgress += progressMap[item.file.path] ?? 0.0;
        _uploadProgress = (totalProgress / allItems.length).clamp(0.0, 1.0);
        notifyListeners();
      }

      final folderItems = allItems.where((item) => item.isFolder).toList();
      folderItems.sort(
        (a, b) => a.relativePathForTree
            .split('/')
            .length
            .compareTo(b.relativePathForTree.split('/').length),
      );

      for (var item in folderItems) {
        await resolveOrCreateFolderTree(
          item.relativePathForTree,
          item.targetFolderId,
        );
        progressMap[item.file.path] = 1.0;
        _pendingUploads.remove(item);
        updateOverallProgress();
      }

      final fileItems = allItems.where((item) => !item.isFolder).toList();
      const int maxConcurrent = 3;

      while (fileItems.isNotEmpty) {
        final batch = fileItems.take(maxConcurrent).toList();
        for (var item in batch) fileItems.remove(item);

        _currentlyUploadingName = batch
            .map((e) => e.file.name.split('/').last)
            .join(', ');
        notifyListeners();

        List<Future<void>> uploadTasks = [];

        for (var item in batch) {
          int finalTargetFolderId = await resolveOrCreateFolderTree(
            item.relativePathForTree,
            item.targetFolderId,
          );

          uploadTasks.add(
            SyncService.uploadFileInChunks(
              file: File(item.file.path),
              folderId: finalTargetFolderId,
              onProgress: (progress) {
                progressMap[item.file.path] = progress;
                updateOverallProgress();
              },
            ).then((success) {
              progressMap[item.file.path] = 1.0;
              _pendingUploads.remove(item);
              updateOverallProgress();
            }),
          );
        }
        await Future.wait(uploadTasks);
      }
    }

    _isUploading = false;
    _uploadProgress = 1.0;
    _currentlyUploadingName = '';
    await fetchData();
    notifyListeners();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _syncStatus = '';
    notifyListeners();

    try {
      final localData = await LocalStorageService.loadLocalData();
      if (localData.folders.isNotEmpty || localData.files.isNotEmpty) {
        _allFolders = localData.folders;
        _allFiles = localData.files;
        notifyListeners();
      }
    } catch (e) {}

    await fetchWorkspaces();
    final result = await SyncService.syncFiles();
    _allFolders = result.folders;
    _allFiles = result.files;

    _isLoading = false;
    notifyListeners();
  }

  void navigateToFolder(FolderItem folder) {
    _navigationStack.add(folder.folderId);
    _searchQuery = '';
    clearSelection();
    closeInfoPanel();
    notifyListeners();
  }

  void goBack() {
    if (!isAtRoot) {
      _navigationStack.removeLast();
      _searchQuery = '';
      clearSelection();
      closeInfoPanel();
      notifyListeners();
    }
  }

  Future<void> createFolder(String folderName) async {
    _isLoading = true;
    notifyListeners();
    final newFolder = await SyncService.createFolder(
      folderName,
      currentFolderId,
    );
    if (newFolder != null) {
      _allFolders.add(newFolder);
      _updateSyncStatus("✅ '${newFolder.folderName}' oluşturuldu.");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> moveToTrash() async {
    _isLoading = true;
    notifyListeners();

    final List<FolderItem> foldersToDelete = _selectedFolders.toList();
    final List<FileItem> filesToDelete = _selectedFiles.toList();

    if (await SyncService.trashItems(
      folders: foldersToDelete,
      files: filesToDelete,
    )) {
      await fetchData();
      _updateSyncStatus('🗑️ Öğeler Geri Dönüşüm Kutusuna taşındı.');
    } else {
      _updateSyncStatus('❌ Öğeler silinemedi.');
    }

    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deletePermanently() async {
    _isLoading = true;
    notifyListeners();

    final List<FolderItem> foldersToDelete = _selectedFolders.toList();
    final List<FileItem> filesToDelete = _selectedFiles.toList();
    int successFileCount = 0;
    int successFolderCount = 0;

    for (var file in filesToDelete) {
      if (await SyncService.deleteFile(file)) {
        successFileCount++;
        _allFiles.remove(file);
      }
    }

    for (var folder in foldersToDelete) {
      if (await SyncService.deleteFolder(folder) == null) {
        successFolderCount++;
        _allFolders.remove(folder);
      }
    }

    _updateSyncStatus(
      '✅ $successFolderCount klasör, $successFileCount dosya kalıcı olarak silindi.',
    );
    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> restoreSelected() async {
    _isLoading = true;
    notifyListeners();

    if (await SyncService.restoreItems(
      folders: _selectedFolders.toList(),
      files: _selectedFiles.toList(),
    )) {
      await fetchData();
      _updateSyncStatus('✅ Öğeler başarıyla geri yüklendi.');
    } else {
      _updateSyncStatus('❌ Öğeler geri yüklenemedi.');
    }

    clearSelection();
    closeInfoPanel();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameFolder(FolderItem folder, String newName) async {
    _isLoading = true;
    notifyListeners();
    final updatedFolder = await SyncService.renameFolder(folder, newName);
    if (updatedFolder != null) {
      final index = _allFolders.indexWhere(
        (f) => f.folderId == folder.folderId,
      );
      if (index != -1) _allFolders[index] = updatedFolder;
      _updateSyncStatus("✅ Klasör adı güncellendi.");
      clearSelection();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> moveSelectedItems(int targetFolderId) async {
    _isLoading = true;
    notifyListeners();
    final errorMessage = await SyncService.moveItems(
      folders: _selectedFolders.toList(),
      files: _selectedFiles.toList(),
      targetFolderId: targetFolderId,
    );
    if (errorMessage == null) {
      fetchData();
      clearSelection();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameFile(FileItem file, String newName) async {
    _isLoading = true;
    notifyListeners();
    String oldExtension = file.fileName.contains('.')
        ? file.fileName.split('.').last
        : "";
    String finalNewName = newName.trim();
    if (oldExtension.isNotEmpty && !finalNewName.endsWith('.$oldExtension'))
      finalNewName = '$finalNewName.$oldExtension';

    final updatedFile = await SyncService.renameFile(file, finalNewName);
    if (updatedFile != null) {
      final index = _allFiles.indexWhere((f) => f.fileUrl == file.fileUrl);
      if (index != -1)
        _allFiles[index] = updatedFile.copyWith(
          lastUpdated: DateTime.now().toIso8601String(),
        );
      _updateSyncStatus("✅ Dosya adı güncellendi.");
    }
    _isLoading = false;
    notifyListeners();
  }

  void toggleFileSelection(FileItem file) {
    if (_selectedFiles.contains(file))
      _selectedFiles.remove(file);
    else
      _selectedFiles.add(file);
    notifyListeners();
  }

  void toggleFolderSelection(FolderItem folder) {
    if (_selectedFolders.contains(folder))
      _selectedFolders.remove(folder);
    else
      _selectedFolders.add(folder);
    notifyListeners();
  }

  void selectAll({bool isTrash = false}) {
    if (isTrash) {
      _selectedFolders.addAll(trashFolders);
      _selectedFiles.addAll(trashFiles);
    } else {
      _selectedFolders.addAll(activeFolders);
      _selectedFiles.addAll(activeFiles);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedFolders.clear();
    _selectedFiles.clear();
    notifyListeners();
  }

  void updateMarqueeSelection(
    List<dynamic> intersectingItems, {
    required Set<dynamic> preDragSelection,
  }) {
    _selectedFolders.clear();
    _selectedFiles.clear();

    for (var item in preDragSelection) {
      if (item is FolderItem) _selectedFolders.add(item);
      if (item is FileItem) _selectedFiles.add(item);
    }

    for (var item in intersectingItems) {
      if (item is FolderItem) _selectedFolders.add(item);
      if (item is FileItem) _selectedFiles.add(item);
    }
    notifyListeners();
  }

  Future<int> resolveOrCreateFolderTree(
    String relativePath,
    int rootFolderId,
  ) async {
    if (relativePath.isEmpty || relativePath == '/' || relativePath == '.')
      return rootFolderId;

    final parts = relativePath
        .split('/')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    int currentParentId = rootFolderId;

    for (var part in parts) {
      final existingFolders = _allFolders.where(
        (f) => f.parentId == currentParentId && f.folderName == part,
      );
      if (existingFolders.isNotEmpty) {
        currentParentId = existingFolders.first.folderId;
      } else {
        final newFolder = await SyncService.createFolder(part, currentParentId);
        if (newFolder != null) {
          _allFolders.add(newFolder);
          currentParentId = newFolder.folderId;
          notifyListeners();
        } else {
          return currentParentId;
        }
      }
    }
    return currentParentId;
  }

  Future<void> handlePaths(
    List<String> paths, {
    int? customTargetFolderId,
  }) async {
    final targetFolderId = customTargetFolderId ?? currentFolderId;
    _isLoading = true;
    notifyListeners();
    int addedCount = 0;

    for (String path in paths) {
      try {
        final normalizedPath = path.replaceAll('\\', '/');
        final entityType = await FileSystemEntity.type(normalizedPath);

        if (entityType == FileSystemEntityType.directory) {
          final dir = Directory(normalizedPath);
          final parentPath = dir.parent.path.replaceAll('\\', '/');
          bool isEmpty = true;

          await for (var entity
              in dir
                  .list(recursive: true, followLinks: false)
                  .handleError((e) {})) {
            isEmpty = false;
            final entityNormPath = entity.path.replaceAll('\\', '/');
            String relativePath = entityNormPath.replaceFirst(
              '$parentPath/',
              '',
            );

            if (entity is File) {
              String relativeDir = relativePath.contains('/')
                  ? relativePath.substring(0, relativePath.lastIndexOf('/'))
                  : '';
              addProgrammaticUpload(
                file: XFile(entityNormPath),
                targetFolderId: targetFolderId,
                targetFolderName: relativeDir.isEmpty
                    ? currentFolderName
                    : relativeDir,
                isFolder: false,
                relativePathForTree: relativeDir,
              );
              addedCount++;
            } else if (entity is Directory) {
              bool isSubEmpty = true;
              try {
                if (entity.listSync().isNotEmpty) isSubEmpty = false;
              } catch (e) {}
              if (isSubEmpty) {
                addProgrammaticUpload(
                  file: XFile(entityNormPath),
                  targetFolderId: targetFolderId,
                  targetFolderName: relativePath,
                  isFolder: true,
                  relativePathForTree: relativePath,
                );
                addedCount++;
              }
            }
          }

          if (isEmpty) {
            String relativePath = normalizedPath.replaceFirst(
              '$parentPath/',
              '',
            );
            addProgrammaticUpload(
              file: XFile(normalizedPath),
              targetFolderId: targetFolderId,
              targetFolderName: relativePath,
              isFolder: true,
              relativePathForTree: relativePath,
            );
            addedCount++;
          }
        } else if (entityType == FileSystemEntityType.file) {
          addProgrammaticUpload(
            file: XFile(normalizedPath),
            targetFolderId: targetFolderId,
            targetFolderName: currentFolderName,
            isFolder: false,
            relativePathForTree: '',
          );
          addedCount++;
        }
      } catch (e) {}
    }

    if (addedCount == 0)
      _updateSyncStatus("Kuyruğa eklenecek yeni öğe bulunamadı.");
    else
      _updateSyncStatus(
        "⏳ $addedCount öğe kuyruğa eklendi, onayınız bekleniyor.",
      );

    _isLoading = false;
    notifyListeners();
  }

  // =====================================================================
  // 📥 KESİNTİSİZ ASENKRON İNDİRME MOTORU
  // =====================================================================
  final List<DownloadItem> _activeDownloads = [];
  List<DownloadItem> get activeDownloads => _activeDownloads;

  Future<void> startDownload(FileItem file) async {
    String url = file.fileUrl;
    if (!url.startsWith('http')) {
      url = "https://mostromo.com/connect/$url";
    }

    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final mostromoDir = Directory('${dir.path}/Mostromo');
    if (!await mostromoDir.exists()) {
      await mostromoDir.create(recursive: true);
    }

    final savePath = '${mostromoDir.path}/${file.fileName}';

    if (_activeDownloads.any((item) => item.id == file.fileUrl)) return;

    final newItem = DownloadItem(
      id: file.fileUrl,
      fileName: file.fileName,
      url: url,
      savePath: savePath,
    );

    _activeDownloads.add(newItem);
    notifyListeners();

    _processDownload(newItem);
  }

  Future<void> _processDownload(DownloadItem item) async {
    item.cancelToken = CancelToken();
    item.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final file = File(item.savePath);
      int startByte = 0;

      if (await file.exists()) {
        startByte = await file.length();
      }

      final dio = Dio();

      final options = Options(
        responseType: ResponseType.stream,
        headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : {},
      );

      final response = await dio.get<ResponseBody>(
        item.url,
        cancelToken: item.cancelToken,
        options: options,
      );

      if (item.totalBytes == 0) {
        final contentRange = response.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        if (contentRange != null) {
          item.totalBytes = int.parse(contentRange.split('/').last);
        } else {
          final contentLength = response.headers.value(
            HttpHeaders.contentLengthHeader,
          );
          if (contentLength != null) {
            item.totalBytes = int.parse(contentLength) + startByte;
          }
        }
      }

      if (response.statusCode == 200 && startByte > 0) {
        startByte = 0;
        await file.writeAsBytes([]);
      }

      if (startByte == item.totalBytes && item.totalBytes > 0) {
        item.progress = 1.0;
        item.status = DownloadStatus.completed;
        notifyListeners();
        return;
      }

      final raf = await file.open(mode: FileMode.append);
      final stream = response.data!.stream;

      int downloaded = startByte;
      final stopwatch = Stopwatch()..start();

      await for (var chunk in stream) {
        if (item.cancelToken!.isCancelled) break;

        await raf.writeFrom(chunk);
        downloaded += chunk.length;
        item.downloadedBytes = downloaded;

        if (item.totalBytes > 0) {
          item.progress = downloaded / item.totalBytes;

          if (stopwatch.elapsedMilliseconds > 100 ||
              downloaded == item.totalBytes) {
            notifyListeners();
            stopwatch.reset();
          }
        } else {
          if (stopwatch.elapsedMilliseconds > 100) {
            notifyListeners();
            stopwatch.reset();
          }
        }
      }

      await raf.close();

      if (!item.cancelToken!.isCancelled) {
        item.status = DownloadStatus.completed;
        notifyListeners();
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        item.status = DownloadStatus.paused;
      } else {
        item.status = DownloadStatus.error;
      }
      notifyListeners();
    }
  }

  void pauseDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      _activeDownloads[index].cancelToken?.cancel("Duraklatıldı");
    }
  }

  void resumeDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      _processDownload(_activeDownloads[index]);
    }
  }

  void cancelDownload(String id) {
    final index = _activeDownloads.indexWhere((e) => e.id == id);
    if (index != -1) {
      final item = _activeDownloads[index];
      item.cancelToken?.cancel("İptal Edildi");
      final file = File(item.savePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _activeDownloads.removeAt(index);
      notifyListeners();
    }
  }

  void clearCompletedDownloads() {
    _activeDownloads.removeWhere(
      (item) => item.status == DownloadStatus.completed,
    );
    if (_activeDownloads.isEmpty) notifyListeners();
  }
}
*/
