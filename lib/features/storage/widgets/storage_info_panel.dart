// lib/features/storage/widgets/storage_info_panel.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';
import '../viewmodels/storage_view_model.dart';

class StorageInfoPanel extends StatelessWidget {
  final StorageViewModel viewModel;

  const StorageInfoPanel({super.key, required this.viewModel});

  // 🌟 GÜVENLİ BOYUT OKUYUCU (Gelen veri int veya String olabilir)
  int _parseSizeSafely(dynamic size) {
    if (size == null || size.toString().isEmpty) return 0;
    if (size is int) return size;
    if (size is double) return size.toInt();
    if (size is String) return int.tryParse(size) ?? 0;
    return 0;
  }

  // Boyutu KB, MB, GB formatına çevirir
  String _formatBytes(dynamic size) {
    int bytes = _parseSizeSafely(size);
    if (bytes <= 0) return "0 B";

    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();

    if (i >= suffixes.length) i = suffixes.length - 1;

    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  // Dosya uzantısına göre dinamik ikon ve renk belirleyici
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
        return (Icons.insert_drive_file_rounded, ThemeColors.primary);
    }
  }

  // Tarih Formatlayıcı
  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "Bilinmiyor";
    try {
      final date = DateTime.parse(rawDate);
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = viewModel.activeItem;

    if (item == null) {
      return Center(
        child: Text(
          "Öğe Seçilmedi",
          style: TextStyle(
            color: ThemeColors.captionText,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final bool isFolder = item is FolderItem;
    final String name = isFolder
        ? item.folderName
        : (item as FileItem).fileName;
    final String extension = isFolder
        ? "Klasör"
        : (item as FileItem).fileExtension;

    String formattedSize = "0 B";
    String itemsCountText = "";
    String createdAt = "--";

    // 🌟 SİHİRLİ DOKUNUŞ: KLASÖR İÇERİĞİ VE BOYUTU HESAPLAYICISI
    if (isFolder) {
      int totalSize = 0;
      int totalItems = 0;

      // Matruşka (Özyineli - Recursive) Fonksiyon
      void calculateFolderStats(int targetFolderId) {
        // 1. Bu klasörün içindeki dosyaları bul ve boyutlarını topla
        final filesInFolder = viewModel.allFiles.where(
          (f) => f.folderId == targetFolderId,
        );
        totalItems += filesInFolder.length;
        for (var file in filesInFolder) {
          totalSize += _parseSizeSafely(file.fileSize);
        }

        // 2. Bu klasörün alt klasörlerini bul ve kendini tekrar çağır (Daha da derine in)
        final subFolders = viewModel.allFolders.where(
          (f) => f.parentId == targetFolderId,
        );
        totalItems += subFolders.length;
        for (var subFolder in subFolders) {
          calculateFolderStats(subFolder.folderId);
        }
      }

      // Tıklanan klasörden hesaplamayı başlat
      calculateFolderStats(item.folderId);

      formattedSize = _formatBytes(totalSize);
      itemsCountText = "$totalItems Öğe";
    } else {
      // Eğer bir dosyaysa, sadece kendi boyutunu ve tarihini göster
      formattedSize = _formatBytes((item as FileItem).fileSize);
      createdAt = _formatDate((item as FileItem).createdAt);
    }

    // İkon ve Renk Belirleme
    IconData displayIcon;
    Color displayColor;

    if (isFolder) {
      displayIcon = Icons.folder_rounded;
      displayColor = Colors.orangeAccent;
    } else {
      final appearance = _getFileAppearance(extension, name);
      displayIcon = appearance.$1;
      displayColor = appearance.$2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- ÜST BAR (Kapatma Butonu ve Başlık) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Öğe Detayları",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.titleText,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: ThemeColors.captionText),
                onPressed: () => viewModel.closeInfoPanel(),
                splashRadius: 20,
              ),
            ],
          ),
        ),

        Divider(height: 1, color: ThemeColors.titleText.withOpacity(0.05)),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- DİNAMİK İKON VE RENK ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(displayIcon, size: 64, color: displayColor),
                ),
                const SizedBox(height: 20),

                // --- İSİM ---
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.titleText,
                  ),
                ),
                const SizedBox(height: 32),

                // --- BİLGİ LİSTESİ ---
                _buildInfoRow(
                  Icons.info_outline_rounded,
                  "Tür",
                  isFolder ? "Klasör" : "${extension.toUpperCase()} Dosyası",
                ),
                _buildInfoRow(Icons.sd_storage_rounded, "Boyut", formattedSize),

                // Klasörse İçerik miktarını göster, Dosyaysa Oluşturulma tarihini göster
                if (isFolder)
                  _buildInfoRow(
                    Icons.folder_copy_rounded,
                    "İçerik",
                    itemsCountText,
                  ),
                if (!isFolder)
                  _buildInfoRow(
                    Icons.calendar_month_rounded,
                    "Tarih",
                    createdAt,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: ThemeColors.captionText),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeColors.captionText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeColors.titleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
