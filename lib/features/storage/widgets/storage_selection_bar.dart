// lib/features/storage/widgets/storage_selection_bar.dart

import 'package:flutter/material.dart';
import 'package:common_ui/data/theme_colors.dart';
import '../viewmodels/storage_view_model.dart';

class StorageSelectionBar extends StatelessWidget {
  final StorageViewModel viewModel;
  final VoidCallback onTrashTap;

  const StorageSelectionBar({
    super.key,
    required this.viewModel,
    required this.onTrashTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  onPressed: () => viewModel.selectAll(isTrash: false),
                  icon: const Icon(Icons.select_all_rounded),
                  label: const Text("Tümünü Seç"),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.drive_file_move_rounded,
                    color: Colors.blue,
                  ),
                  onPressed: () {},
                  tooltip: "Taşı",
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: Colors.redAccent,
                  ),
                  onPressed: onTrashTap,
                  tooltip: "Çöpe At",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
