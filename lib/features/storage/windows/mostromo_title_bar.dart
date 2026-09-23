// lib/core/widgets/mostromo_title_bar.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:common_ui/data/theme_colors.dart';

class MostromoTitleBar extends StatelessWidget {
  final double height;
  final Color? backgroundColor;
  final VoidCallback? onClose;
  final String title;

  const MostromoTitleBar({
    super.key,
    this.height = 48.0,
    this.backgroundColor,
    this.onClose,
    this.title = 'Mostromo Connect',
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOS =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (!isDesktopOS) {
      return const SizedBox.shrink(); // Mobilde title bar'a gerek yok
    }

    return Container(
      height: height,
      // 🌟 DEĞİŞİKLİK 1: Transparan yerine temanın orijinal SİYAH (Zemin) rengi atandı.
      color: backgroundColor ?? ThemeColors.background,
      child: Row(
        children: [
          const SizedBox(width: 16),
          // 🌟 DEĞİŞİKLİK 2: Bulut ikonu yerine orijinal Uygulama İkonu eklendi
          Image.asset(
            'assets/app_icon.png',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              color: ThemeColors.titleText.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),

          _buildWindowButton(
            Icons.minimize_rounded,
            () => windowManager.minimize(),
          ),
          _buildWindowButton(Icons.crop_square_rounded, () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          }),
          _buildWindowButton(
            Icons.close_rounded,
            onClose ?? () => windowManager.close(),
            isClose: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton(
    IconData icon,
    VoidCallback onTap, {
    bool isClose = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isClose ? Colors.redAccent : Colors.white10,
        child: Container(
          width: 46,
          height: double.infinity,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
      ),
    );
  }
}
