// lib/features/storage/windows/upload_windows_page.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';
import 'package:file_picker/file_picker.dart';

class UploadWindowsPage extends StatefulWidget {
  const UploadWindowsPage({super.key});

  @override
  State<UploadWindowsPage> createState() => _UploadWindowsPageState();
}

class _UploadWindowsPageState extends State<UploadWindowsPage> {
  bool _isDragging = false;

  Future<void> _pick(
    BuildContext context,
    StorageViewModel viewModel,
    String type,
  ) async {
    if (viewModel.isUploading) return;

    if (type == 'file') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: 'Mostromo: Yüklenecek Dosyaları Seçin',
      );
      if (result != null) {
        List<String> paths = result.paths.whereType<String>().toList();
        viewModel.handlePaths(paths);
      }
    } else if (type == 'folder') {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Mostromo: Yüklenecek Klasörü Seçin',
      );
      if (selectedDirectory != null) {
        viewModel.handlePaths([selectedDirectory]);
      }
    }
  }

  void _showEmptyStatePicker(BuildContext context, StorageViewModel viewModel) {
    if (viewModel.isUploading) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColors.floatingPanelColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Ne Yüklemek İstiyorsunuz?",
          style: TextStyle(
            color: ThemeColors.titleText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Lütfen yüklemek istediğiniz veri tipini seçin.",
          style: TextStyle(color: ThemeColors.captionText),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(context, viewModel, 'file');
            },
            icon: const Icon(
              Icons.insert_drive_file_rounded,
              color: Colors.blueAccent,
            ),
            label: Text(
              "Dosyalar",
              style: TextStyle(
                color: ThemeColors.titleText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _pick(context, viewModel, 'folder');
            },
            icon: const Icon(Icons.folder_rounded),
            label: const Text(
              "Klasör",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StorageViewModel>();
    final uploadList = viewModel.pendingUploads;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        if (!viewModel.isUploading) {
          final paths = details.files.map((file) => file.path).toList();
          viewModel.handlePaths(paths);
        }
      },
      child: Scaffold(
        backgroundColor: ThemeColors.background,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ŞIK BAŞLIK ---
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: ThemeColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: viewModel.isUploading
                              ? null
                              : () => context.go('/'),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: viewModel.isUploading
                                ? Colors.grey
                                : ThemeColors.titleText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Gönderim Kuyruğu",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: ThemeColors.titleText,
                            ),
                          ),
                          Text(
                            "Dosyalarınızı hazırlayın ve tek tuşla buluta fırlatın.",
                            style: TextStyle(
                              color: ThemeColors.captionText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- LİSTE ALANI ---
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: ThemeColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: _isDragging
                              ? ThemeColors.primary.withOpacity(0.5)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: uploadList.isEmpty
                            ? _buildEmptyState(context, viewModel)
                            : _buildFilesList(viewModel, uploadList),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- YÜKLEME DURUMU (PROGRESS BAR) ---
                  if (viewModel.isUploading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Buluta senkronize ediliyor...",
                                style: TextStyle(
                                  color: ThemeColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                "%${(viewModel.uploadProgress * 100).toInt()}",
                                style: TextStyle(
                                  color: ThemeColors.titleText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: viewModel.uploadProgress,
                              backgroundColor: ThemeColors.primary.withOpacity(
                                0.1,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeColors.primary,
                              ),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- MODERN ALT BUTONLAR ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: "Yeni Ekle",
                        offset: const Offset(0, -120),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: ThemeColors.surface,
                        elevation: 10,
                        enabled: !viewModel.isUploading,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: viewModel.isUploading
                                ? Colors.grey.withOpacity(0.1)
                                : ThemeColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: viewModel.isUploading
                                    ? Colors.grey
                                    : ThemeColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Listeye Ekle",
                                style: TextStyle(
                                  color: viewModel.isUploading
                                      ? Colors.grey
                                      : ThemeColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: viewModel.isUploading
                                    ? Colors.grey
                                    : ThemeColors.primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'file',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file_rounded,
                                  color: Colors.blueAccent,
                                ),
                                SizedBox(width: 12),
                                Text("Dosya Ekle"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'folder',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_rounded,
                                  color: Colors.orangeAccent,
                                ),
                                SizedBox(width: 12),
                                Text("Klasör Ekle"),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) => _pick(context, viewModel, value),
                      ),

                      const Spacer(),

                      TextButton.icon(
                        onPressed: (uploadList.isEmpty || viewModel.isUploading)
                            ? null
                            : () => viewModel.clearPendingUploads(),
                        icon: Icon(
                          Icons.delete_sweep_rounded,
                          color: (uploadList.isEmpty || viewModel.isUploading)
                              ? Colors.grey
                              : Colors.redAccent.withOpacity(0.8),
                        ),
                        label: Text(
                          "Kuyruğu Temizle",
                          style: TextStyle(
                            color: (uploadList.isEmpty || viewModel.isUploading)
                                ? Colors.grey
                                : Colors.redAccent.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: (uploadList.isEmpty || viewModel.isUploading)
                            ? null
                            : () => viewModel.startUpload(),
                        icon: viewModel.isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          viewModel.isUploading
                              ? "Yükleniyor..."
                              : "Yüklemeyi Başlat",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColors.primary,
                          foregroundColor: Colors.white,
                          elevation: uploadList.isEmpty ? 0 : 6,
                          shadowColor: ThemeColors.primary.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- MUHTEŞEM SÜRÜKLE BIRAK EFEKTİ (GLASSMORPHISM) ---
            if (_isDragging)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: ThemeColors.background.withOpacity(0.5),
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
                                    color: ThemeColors.primary.withOpacity(0.3),
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
                                    "Buraya Bırak",
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
    );
  }

  Widget _buildEmptyState(BuildContext context, StorageViewModel viewModel) {
    if (viewModel.isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Lütfen bekleyin, dosyalar işleniyor...",
              style: TextStyle(
                fontSize: 18,
                color: ThemeColors.titleText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmptyStatePicker(context, viewModel),
        hoverColor: ThemeColors.primary.withOpacity(0.02),
        splashColor: ThemeColors.primary.withOpacity(0.05),
        child: Center(
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
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: ThemeColors.primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Kuyruk Bomboş",
                style: TextStyle(
                  fontSize: 22,
                  color: ThemeColors.titleText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Dosyaları buraya sürükleyin veya seçmek için tıklayın.",
                style: TextStyle(fontSize: 15, color: ThemeColors.captionText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilesList(
    StorageViewModel viewModel,
    List<UploadItem> uploadList,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: uploadList.length,
      itemBuilder: (context, index) {
        final item = uploadList[index];
        double sizeInKb = 0;

        // Eğer klasörse boyut hesaplamaya çalışma
        if (!item.isFolder) {
          try {
            sizeInKb = File(item.file.path).lengthSync() / 1024;
          } catch (e) {
            sizeInKb = 0;
          }
        }

        // Windows/Mac yollarını temizleyip sadece dosya/klasör adını almak için
        String displayName = item.file.name.split('/').last.split('\\').last;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ThemeColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeColors.titleText.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Klasörse turuncu, dosyaysa mavi konsepti
                color: item.isFolder
                    ? Colors.orangeAccent.withOpacity(0.1)
                    : ThemeColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.isFolder
                    ? Icons.folder_rounded
                    : Icons.insert_drive_file_rounded,
                color: item.isFolder
                    ? Colors.orangeAccent
                    : ThemeColors.primary,
              ),
            ),
            title: Text(
              displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeColors.titleText,
                fontSize: 15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Icon(
                    item.isFolder
                        ? Icons.create_new_folder_outlined
                        : Icons.folder_open_rounded,
                    size: 14,
                    color: ThemeColors.captionText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isFolder
                        ? "Klasör oluşturulacak"
                        : item.targetFolderName,
                    style: TextStyle(
                      color: ThemeColors.captionText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!item.isFolder) ...[
                    const SizedBox(width: 12),
                    Text(
                      "•  " +
                          (sizeInKb > 1024
                              ? "${(sizeInKb / 1024).toStringAsFixed(2)} MB"
                              : "${sizeInKb.toStringAsFixed(2)} KB"),
                      style: TextStyle(color: ThemeColors.captionText),
                    ),
                  ],
                ],
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                size: 24,
                color: viewModel.isUploading
                    ? Colors.grey
                    : Colors.redAccent.withOpacity(0.7),
              ),
              onPressed: viewModel.isUploading
                  ? null
                  : () => viewModel.removePendingUpload(index),
              tooltip: "Kuyruktan Çıkar",
            ),
          ),
        );
      },
    );
  }
}
