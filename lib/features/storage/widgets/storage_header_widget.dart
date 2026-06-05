// lib/features/storage/widgets/storage_header_widget.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:common_ui/data/theme_colors.dart';
import '../viewmodels/storage_view_model.dart';

class StorageHeaderWidget extends StatelessWidget {
  final StorageViewModel viewModel;
  final VoidCallback onCreateFolderTap;

  const StorageHeaderWidget({
    super.key,
    required this.viewModel,
    required this.onCreateFolderTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15 * 0.5, sigmaY: 15 * 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: ThemeColors.sidePanelColor.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: ThemeColors.titleText.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // =========================================================
              // 1. SOL KISIM: Geri/İleri Butonları ve Yol Haritası
              // =========================================================
              Expanded(
                child: Row(
                  children: [
                    // 🌟 YENİ: TARAYICI (BROWSER) STİLİ GERİ VE İLERİ BUTON GRUBU
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: ThemeColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ThemeColors.titleText.withValues(alpha: 0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // GERİ BUTONU (<)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: viewModel.canGoBack
                                ? ThemeColors.titleText
                                : ThemeColors.captionText.withValues(
                                    alpha: 0.3,
                                  ),
                            onPressed: viewModel.canGoBack
                                ? () => viewModel.goBack()
                                : null,
                            tooltip: "Geri",
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: ThemeColors.titleText.withValues(
                              alpha: 0.05,
                            ),
                          ),
                          // İLERİ BUTONU (>)
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            color: viewModel.canGoForward
                                ? ThemeColors.titleText
                                : ThemeColors.captionText.withValues(
                                    alpha: 0.3,
                                  ),
                            onPressed: viewModel.canGoForward
                                ? () => viewModel.goForward()
                                : null,
                            tooltip: "İleri",
                          ),
                        ],
                      ),
                    ),

                    // KAYDIRILABİLİR YOL HARİTASI
                    Expanded(child: _BreadcrumbTrail(viewModel: viewModel)),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // =========================================================
              // 2. SAĞ KISIM: Sabit Boyutlu Butonlar ve Arama
              // =========================================================
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 240,
                    height: 44,
                    child: TextField(
                      onChanged: (value) => viewModel.setSearchQuery(value),
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.titleText,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ThemeColors.titleText.withValues(
                          alpha: 0.04,
                        ),
                        hintText:
                            "${viewModel.currentFolderName} içinde ara...",
                        hintStyle: TextStyle(
                          color: ThemeColors.captionText.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: ThemeColors.captionText,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: ThemeColors.titleText.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: ThemeColors.primary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  _buildSortMenu(context),
                  const SizedBox(width: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: ThemeColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ThemeColors.titleText.withValues(alpha: 0.05),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => viewModel.toggleViewMode(),
                      icon: Icon(
                        viewModel.isListView
                            ? Icons.grid_view_rounded
                            : Icons.view_list_rounded,
                        color: ThemeColors.titleText,
                      ),
                      tooltip: viewModel.isListView
                          ? "Izgara Görünümü"
                          : "Liste Görünümü",
                    ),
                  ),
                  const SizedBox(width: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: ThemeColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ThemeColors.titleText.withValues(alpha: 0.05),
                      ),
                    ),
                    child: IconButton(
                      onPressed: onCreateFolderTap,
                      icon: Icon(
                        Icons.create_new_folder_rounded,
                        color: ThemeColors.titleText,
                      ),
                      tooltip: "Yeni Klasör",
                    ),
                  ),
                  const SizedBox(width: 12),

                  ElevatedButton.icon(
                    onPressed: () => context.go('/upload'),
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text(
                      "Dosya Yükle",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: ThemeColors.primary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ThemeColors.titleText.withValues(alpha: 0.05),
        ),
      ),
      child: PopupMenuButton<SortType>(
        tooltip: "Sıralama Seçenekleri",
        icon: Icon(Icons.sort_rounded, color: ThemeColors.titleText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: ThemeColors.surface,
        elevation: 12,
        offset: const Offset(0, 48),
        itemBuilder: (context) => [
          _buildSortMenuItem(
            viewModel,
            SortType.name,
            Icons.sort_by_alpha_rounded,
            "İsme Göre",
          ),
          _buildSortMenuItem(
            viewModel,
            SortType.date,
            Icons.calendar_today_rounded,
            "Tarihe Göre",
          ),
          _buildSortMenuItem(
            viewModel,
            SortType.size,
            Icons.data_usage_rounded,
            "Boyuta Göre",
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SortType> _buildSortMenuItem(
    StorageViewModel viewModel,
    SortType type,
    IconData icon,
    String label,
  ) {
    final isSelected = viewModel.sortType == type;
    return PopupMenuItem<SortType>(
      value: type,
      onTap: () => viewModel.setSortType(type),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? ThemeColors.primary : ThemeColors.captionText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? ThemeColors.primary : ThemeColors.titleText,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              viewModel.sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 18,
              color: ThemeColors.primary,
            ),
        ],
      ),
    );
  }
}

class _BreadcrumbTrail extends StatefulWidget {
  final StorageViewModel viewModel;
  final int pathLength;

  _BreadcrumbTrail({required this.viewModel})
    : pathLength = viewModel.breadcrumbs.length;

  @override
  State<_BreadcrumbTrail> createState() => _BreadcrumbTrailState();
}

class _BreadcrumbTrailState extends State<_BreadcrumbTrail> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void didUpdateWidget(covariant _BreadcrumbTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathLength != widget.pathLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.viewModel.breadcrumbs.asMap().entries.map((entry) {
          final int index = entry.key;
          final folder = entry.value;
          final bool isLast = index == widget.viewModel.breadcrumbs.length - 1;

          return Row(
            children: [
              InkWell(
                onTap: isLast
                    ? null
                    : () => widget.viewModel.navigateToBreadcrumbIndex(index),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    folder.folderName,
                    style: TextStyle(
                      fontSize: isLast ? 20 : 15,
                      fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
                      color: isLast
                          ? ThemeColors.titleText
                          : ThemeColors.captionText,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ThemeColors.captionText.withValues(alpha: 0.5),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
