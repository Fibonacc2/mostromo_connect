// lib/features/storage/my_storage_page.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mostromo_connect/features/storage/mobile/my_storage_mobile.dart';
import 'package:mostromo_connect/features/storage/windows/my_storage_windows.dart';

class MyStoragePage extends StatelessWidget {
  const MyStoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Eğer Windows (veya Web/Masaüstü) ise Desktop UI, değilse Mobile UI
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS;

    if (isDesktop) {
      return const MyStorageWindowsPage();
    } else {
      return const MyStorageMobilePage(); // Eski dosyanın class adı
    }
  }
}
