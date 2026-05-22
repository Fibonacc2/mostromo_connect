// apps/mostromo_connect/lib/core/app_router.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ORTAK (Common & Shared)
import 'package:common_ui/data/theme_colors.dart';
import 'package:mostromo_connect/core/nav_event_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:mostromo_icons/mostromo_icons.dart';

// SAYFALAR
import '../features/storage/my_storage_page.dart';
import '../features/storage/search_page.dart';
import '../features/storage/settings_page.dart';
import '../features/storage/upload_file_page.dart';
import '../features/viewers/storage_pdf_viewer.dart';
import '../features/viewers/storage_text_viewer.dart';
import '../features/viewers/storage_media_viewer.dart';

// MASAÜSTÜ ÖZEL SAYFALARI
import '../features/storage/windows/upload_windows_page.dart';
import '../features/storage/windows/workspaces_page.dart';

// ✅ PLATFORM KONTROLÜ: Rotaları ve Menüleri ayırmak için global değişken
final bool isDesktopOS =
    kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class AppRouter {
  late final GoRouter router;
  static const MethodChannel _platform = MethodChannel(
    'mostromo_connect/shareFile',
  );

  AppRouter() {
    router = GoRouter(
      initialLocation: '/',
      redirect: _handleRedirect,
      routes: [
        // --- 1. GRUP: TAB BAR / YAN MENÜ OLAN SAYFALAR (ShellRoute) ---
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _MainWrapper(navigationShell: navigationShell);
          },
          // ✅ İŞLETİM SİSTEMİNE GÖRE DİNAMİK BRANCH'LER (SEKMELER)
          branches: _buildBranches(),
        ),

        // --- 2. GRUP: TAM EKRAN SAYFALAR ---
        GoRoute(
          path: '/upload_file',
          builder: (context, state) {
            final folderId = state.extra as int? ?? 0;
            return UploadFilePage(folderId: folderId);
          },
        ),

        GoRoute(
          path: '/pdf_viewer',
          builder: (context, state) =>
              PdfViewerPage(file: state.extra as FileItem),
        ),

        GoRoute(
          path: '/text_viewer',
          builder: (context, state) =>
              TextViewerPage(file: state.extra as FileItem),
        ),

        GoRoute(
          path: '/media_viewer',
          builder: (context, state) =>
              StorageMediaViewerPage(item: state.extra as FileItem),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Sayfa bulunamadı: ${state.error}')),
      ),
    );

    _setupPlatformChannel();
  }

  // ✅ MOBİL VE MASAÜSTÜ İÇİN ROTALARI AYARLAYAN YARDIMCI METOT
  List<StatefulShellBranch> _buildBranches() {
    List<StatefulShellBranch> branches = [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MyStoragePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
        ],
      ),
    ];

    // Sadece masaüstü ortamında (Windows/Mac/Web) yükleme ve workspace sayfalarını sekmeye ekle
    if (isDesktopOS) {
      branches.add(
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/upload',
              builder: (context, state) => const UploadWindowsPage(),
            ),
          ],
        ),
      );
      branches.add(
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workspaces',
              builder: (context, state) => const WorkspacesPage(),
            ),
          ],
        ),
      );
    }

    // Ayarlar sekmesi herkes için sonda olmalı
    branches.add(
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    );

    return branches;
  }

  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    if (state.uri.path == '/upload_file') return null;
    final hasShare = await _checkPendingShare();
    if (hasShare) return '/upload_file';
    return null;
  }

  Future<bool> _checkPendingShare() async {
    if (isDesktopOS) return false;

    try {
      final bool? hasShare = await _platform.invokeMethod('hasPendingShare');
      return hasShare ?? false;
    } on PlatformException {
      return false;
    } catch (e) {
      debugPrint("Intent kanalı hatası (Yoksayılabilir): $e");
      return false;
    }
  }

  void _setupPlatformChannel() {
    if (isDesktopOS) return;

    _platform.setMethodCallHandler((call) async {
      if (call.method == "navigateToUpload") {
        router.go('/upload_file');
      }
      return null;
    });
  }
}

// ============================================================================
// 🎯 PLATFORM SEÇİCİ WRAPPER
// ============================================================================
class _MainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _MainWrapper({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Mobil cihazda (Örn: Android Tablet) yan çevrilirse Desktop tasarımını gösterir
    final useDesktopLayout =
        isDesktopOS || MediaQuery.of(context).size.width > 800;

    if (useDesktopLayout) {
      return _DesktopWrapper(navigationShell: navigationShell);
    } else {
      return _MobileWrapper(navigationShell: navigationShell);
    }
  }
}

// ============================================================================
// 🖥️ MASAÜSTÜ (VE BÜYÜK EKRANLI MOBİL) ARAYÜZÜ: Şık Yan Menü
// ============================================================================
class _DesktopWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _DesktopWrapper({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SOL YAN PANEL ---
          NavigationRail(
            extended: true,
            minExtendedWidth: 240,
            backgroundColor: ThemeColors.sidePanelColor,
            useIndicator: true,
            indicatorColor: ThemeColors.primary.withOpacity(0.15),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      MostromoIcons.cloud,
                      size: 28,
                      color: ThemeColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Mostromo",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            selectedLabelTextStyle: TextStyle(
              color: ThemeColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            selectedIconTheme: IconThemeData(
              color: ThemeColors.primary,
              size: 24,
            ),
            unselectedIconTheme: const IconThemeData(
              color: Colors.grey,
              size: 24,
            ),
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              if (index == navigationShell.currentIndex) {
                context.read<NavEventProvider>().notifyDoubleTap(index);
              } else {
                navigationShell.goBranch(index);
              }
            },
            // ✅ DİNAMİK MENÜ ÖĞELERİ
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Dosyalarım'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: Text('Ara'),
              ),
              if (isDesktopOS)
                const NavigationRailDestination(
                  icon: Icon(Icons.cloud_upload_outlined),
                  selectedIcon: Icon(Icons.cloud_upload),
                  label: Text('Yükle'),
                ),
              if (isDesktopOS)
                const NavigationRailDestination(
                  icon: Icon(Icons.business_center_outlined),
                  selectedIcon: Icon(Icons.business_center),
                  label: Text('Workspaces'),
                ),
              const NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Ayarlar'),
              ),
            ],
          ),
          Container(width: 1, color: Colors.grey.withOpacity(0.15)),
          Expanded(child: ClipRRect(child: navigationShell)),
        ],
      ),
    );
  }
}

// ============================================================================
// 📱 MOBİL ARAYÜZ: Gizlenebilir Alt Bar
// ============================================================================
class _MobileWrapper extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _MobileWrapper({required this.navigationShell});

  @override
  State<_MobileWrapper> createState() => _MobileWrapperState();
}

class _MobileWrapperState extends State<_MobileWrapper> {
  bool _isVisible = true;
  double _scrollUpDistance = 0.0;

  @override
  Widget build(BuildContext context) {
    final bool isStoragePage = widget.navigationShell.currentIndex == 0;
    final bool shouldShowBar = isStoragePage ? _isVisible : true;

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double totalBarHeight = 80.0 + bottomPadding;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!isStoragePage || notification is! ScrollUpdateNotification) {
            return false;
          }

          final double delta = notification.scrollDelta ?? 0.0;

          if (delta > 0) {
            _scrollUpDistance += delta.abs();
            if (_isVisible && _scrollUpDistance > 100.0) {
              setState(() {
                _isVisible = false;
                _scrollUpDistance = 0;
              });
            }
          } else if (delta < 0) {
            _scrollUpDistance += delta.abs();
            if (!_isVisible && _scrollUpDistance > 100.0) {
              setState(() {
                _isVisible = true;
                _scrollUpDistance = 0;
              });
            }
          }
          return false;
        },
        child: widget.navigationShell,
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: shouldShowBar ? totalBarHeight : 0.0,
        child: Wrap(
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: shouldShowBar ? Offset.zero : const Offset(0, 1.0),
              child: NavigationBar(
                backgroundColor: ThemeColors.background,
                indicatorColor: ThemeColors.primary.withOpacity(0.5),
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: (index) {
                  if (index == widget.navigationShell.currentIndex) {
                    context.read<NavEventProvider>().notifyDoubleTap(index);
                  } else {
                    widget.navigationShell.goBranch(index);
                  }
                },
                // ✅ DİNAMİK MENÜ ÖĞELERİ (Sadece Mobil Uyumlu Olanlar)
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: 'Dosyalarım',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: 'Ara',
                  ),
                  if (isDesktopOS)
                    const NavigationDestination(
                      icon: Icon(Icons.cloud_upload_outlined),
                      selectedIcon: Icon(Icons.cloud_upload),
                      label: 'Yükle',
                    ),
                  if (isDesktopOS)
                    const NavigationDestination(
                      icon: Icon(Icons.business_center_outlined),
                      selectedIcon: Icon(Icons.business_center),
                      label: 'Workspaces',
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Ayarlar',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
