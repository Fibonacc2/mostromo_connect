// lib/features/storage/widgets/upload_status_panel.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:common_ui/data/theme_colors.dart';
import '../viewmodels/storage_view_model.dart';

class UploadStatusPanel extends StatelessWidget {
  final StorageViewModel viewModel;

  const UploadStatusPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    // Sadece yükleme yapılırken görünür
    if (!viewModel.isUploading) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // CSS'teki --glass-bg mantığına göre yan panel renginden veya yüzeyden beslenir
            color: ThemeColors.sidePanelColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeColors.titleText.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // İkon Alanı
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  color: ThemeColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Metin ve Progress Alanı
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.currentlyUploadingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ThemeColors.titleText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Minimal Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: viewModel.uploadProgress,
                        minHeight: 5,
                        backgroundColor: ThemeColors.titleText.withOpacity(
                          0.05,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ThemeColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Yüzdelik Bilgisi
              Text(
                "%${(viewModel.uploadProgress * 100).toInt()}",
                style: TextStyle(
                  color: ThemeColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
