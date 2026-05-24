// lib/features/storage/widgets/download_status_panel.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:common_ui/data/theme_colors.dart';
import '../viewmodels/storage_view_model.dart';

class DownloadStatusPanel extends StatelessWidget {
  final StorageViewModel viewModel;

  const DownloadStatusPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final downloads = viewModel.activeDownloads;

    if (downloads.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 350),
          decoration: BoxDecoration(
            color: ThemeColors.floatingPanelColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThemeColors.titleText.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ThemeColors.titleText.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: ThemeColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "İndirme Yöneticisi",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.titleText,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (downloads.any(
                      (d) => d.status == DownloadStatus.completed,
                    ))
                      IconButton(
                        icon: Icon(
                          Icons.clear_all_rounded,
                          color: ThemeColors.captionText,
                          size: 20,
                        ),
                        tooltip: "Tamamlananları Temizle",
                        onPressed: () => viewModel.clearCompletedDownloads(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final item = downloads[index];
                    return _buildDownloadItem(context, item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadItem(BuildContext context, DownloadItem item) {
    Color statusColor;
    String statusText;
    IconData actionIcon;
    VoidCallback?
    actionTap; // 🌟 DÜZELTME: Type güvenliği eklendi ve null yapılabilir hale getirildi.

    switch (item.status) {
      case DownloadStatus.downloading:
        statusColor = ThemeColors.primary;
        statusText =
            "İndiriliyor... %${(item.progress * 100).toStringAsFixed(1)}";
        actionIcon = Icons.pause_rounded;
        actionTap = () => viewModel.pauseDownload(item.id);
        break;
      case DownloadStatus.paused:
        statusColor = Colors.orange;
        statusText =
            "Duraklatıldı - %${(item.progress * 100).toStringAsFixed(1)}";
        actionIcon = Icons.play_arrow_rounded;
        actionTap = () => viewModel.resumeDownload(item.id);
        break;
      case DownloadStatus.completed:
        statusColor = Colors.green;
        statusText = "Tamamlandı";
        actionIcon = Icons.check_circle_rounded;
        actionTap =
            null; // 🌟 DÜZELTME: Tamamlandığında buton tamamen pasif (tıklanamaz) olur
        break;
      case DownloadStatus.error:
        statusColor = Colors.redAccent;
        statusText = "Bağlantı Hatası";
        actionIcon = Icons.refresh_rounded;
        actionTap = () => viewModel.resumeDownload(item.id);
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: ThemeColors.titleText,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: ThemeColors.titleText.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.status != DownloadStatus.completed)
                IconButton(
                  icon: Icon(actionIcon, color: statusColor, size: 22),
                  onPressed:
                      actionTap, // Eğer actionTap null ise buton görsel olarak da tıklanamaz olur
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: ThemeColors.captionText,
                  size: 20,
                ),
                onPressed: () => viewModel.cancelDownload(item.id),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
