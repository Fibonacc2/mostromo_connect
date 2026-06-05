// lib/features/storage/widgets/storage_item_widget.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';
import '../viewmodels/storage_view_model.dart';

class StorageItemWidget extends StatelessWidget {
  final dynamic item;
  final bool isFolder;
  final StorageViewModel viewModel;
  final GlobalKey itemKey;
  final bool isCtrlPressed;
  final void Function(TapUpDetails) onSecondaryTap;
  final VoidCallback onDoubleTap;

  const StorageItemWidget({
    super.key,
    required this.item,
    required this.isFolder,
    required this.viewModel,
    required this.itemKey,
    required this.isCtrlPressed,
    required this.onSecondaryTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = isFolder ? item.folderName : item.fileName;
    final appearance = isFolder
        ? (Icons.folder_rounded, Colors.orangeAccent)
        : _getFileAppearance(item.fileExtension, name);

    if (viewModel.isListView) {
      return _buildListItem(context, name, appearance.$1, appearance.$2);
    } else {
      return _buildGridItem(context, name, appearance.$1, appearance.$2);
    }
  }

  Widget _buildGridItem(
    BuildContext context,
    String name,
    IconData icon,
    Color iconColor,
  ) {
    final bool isActive = viewModel.activeItem == item;
    final bool isSelected = isFolder
        ? viewModel.selectedFolders.contains(item)
        : viewModel.selectedFiles.contains(item);

    return GestureDetector(
      key: itemKey,
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onSecondaryTap,
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
                onTap: _handleTap,
                onDoubleTap: onDoubleTap,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color.fromARGB(
                              255,
                              224,
                              224,
                              224,
                            ), //ThemeColors.titleText,
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

  Widget _buildListItem(
    BuildContext context,
    String name,
    IconData icon,
    Color iconColor,
  ) {
    final bool isActive = viewModel.activeItem == item;
    final bool isSelected = isFolder
        ? viewModel.selectedFolders.contains(item)
        : viewModel.selectedFiles.contains(item);

    String sizeText = "--";
    String dateText = "--";
    if (!isFolder && item is FileItem) {
      sizeText = _formatFileSize((item as FileItem).fileSize);
      dateText = _formatDate(
        (item as FileItem).lastUpdated ?? (item as FileItem).createdAt,
      );
    }

    return GestureDetector(
      key: itemKey,
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onSecondaryTap,
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? ThemeColors.primary
                    : (isActive
                          ? iconColor.withOpacity(0.5)
                          : ThemeColors.titleText.withOpacity(0.05)),
                width: isSelected ? 2 : (isActive ? 2 : 1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                hoverColor: iconColor.withOpacity(0.05),
                onTap: _handleTap,
                onDoubleTap: onDoubleTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 24, color: iconColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ThemeColors.titleText,
                          ),
                        ),
                      ),
                      if (!isFolder) ...[
                        Expanded(
                          flex: 1,
                          child: Text(
                            sizeText,
                            style: TextStyle(
                              fontSize: 13,
                              color: ThemeColors.captionText,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 13,
                              color: ThemeColors.captionText,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Spacer(flex: 3),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 16,
              right: 16,
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

  void _handleTap() {
    if (isCtrlPressed) {
      if (isFolder)
        viewModel.toggleFolderSelection(item);
      else
        viewModel.toggleFileSelection(item);
    } else {
      if (viewModel.isSelectionMode) viewModel.clearSelection();
      viewModel.selectItem(item);
    }
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    final digitGroups = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, digitGroups)).toStringAsFixed(1)} ${units[digitGroups]}";
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    } catch (e) {
      return dateString;
    }
  }
}
