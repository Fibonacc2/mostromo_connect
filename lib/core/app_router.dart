// apps/mostromo_connect/lib/core/app_router.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ORTAK (Common & Shared)
import 'package:common_ui/data/theme_colors.dart';
import 'package:mostromo_connect/core/nav_event_provider.dart';
import 'package:mostromo_connect/features/storage/mobile/trash_mobile_page.dart';
import 'package:mostromo_connect/features/storage/shared_links_page.dart';
import 'package:mostromo_connect/features/storage/shared_preview_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:mostromo_icons/mostromo_icons.dart';

import '../features/storage/viewmodels/storage_view_model.dart';

// GÜVENLİK VE GİRİŞ
import '../features/auth/login_page.dart';
import 'auth_view_model.dart';

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
import '../features/storage/windows/my_storage_windows.dart';
import '../features/storage/windows/trash_windows_page.dart';

final bool isDesktopOS =
    kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class AppRouter {
  late final GoRouter router;
  final AuthViewModel authViewModel;

  static const MethodChannel _platform = MethodChannel(
    'mostromo_connect/shareFile',
  );

  AppRouter(this.authViewModel) {
    router = GoRouter(
      initialLocation: '/',
      refreshListenable: authViewModel,
      redirect: _handleRedirect,
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

        // 🌟 ASIL PAYLAŞIM ROTASI
        GoRoute(
          path: '/shared_preview',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            return SharedPreviewPage(token: token);
          },
        ),

        // 🌟 WINDOWS/BAZI ANDROID SÜRÜMLERİ İÇİN YEDEK (ALIAS) ROTA
        // (Bazen OS, host ismini de path'in içine dahil ederek gönderir)
        GoRoute(
          path: '/connect/shared_preview',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            return SharedPreviewPage(token: token);
          },
        ),

        // ANA SEKMELİ YAPI
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _MainWrapper(navigationShell: navigationShell);
          },
          branches: _buildBranches(),
        ),

        // TAM EKRAN SAYFALAR
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

  List<StatefulShellBranch> _buildBranches() {
    List<StatefulShellBranch> branches = [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => isDesktopOS
                ? const MyStorageWindowsPage()
                : const MyStoragePage(),
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
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/trash',
            builder: (context, state) => isDesktopOS
                ? const TrashWindowsPage()
                : const TrashMobilePage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/shared_links',
            builder: (context, state) => const SharedLinksPage(),
          ),
        ],
      ),
    ];

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
      ); // İndex: 4
      branches.add(
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workspaces',
              builder: (context, state) => const WorkspacesPage(),
            ),
          ],
        ),
      ); // İndex: 5
    }

    branches.add(
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ); // İndex: Masaüstü için 6, Mobil için 4

    return branches;
  }

  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isLoggedIn = authViewModel.isLoggedIn;
    final path = state.uri.path;

    final isGoingToLogin = path == '/login';
    // 🌟 GÜVENLİK DUVARI BYPASS'I: Ziyaretçi paylaşılan linke mi gidiyor?
    final isGoingToSharedPreview = path.contains('shared_preview');

    // Bekleme (Loading) durumunda hiçbir yönlendirme yapma
    if (authViewModel.isLoading) return null;

    // 🌟 EĞER giriş yapılmamışsa VE gidilen sayfa Login VEYA Paylaşılanlar değilse -> Login'e at.
    if (!isLoggedIn && !isGoingToLogin && !isGoingToSharedPreview) {
      return '/login';
    }

    // Giriş yapılıyken Login'e gidilirse -> Ana sayfaya at
    if (isLoggedIn && isGoingToLogin) {
      return '/';
    }

    if (path == '/upload_file') return null;

    // Paylaşılan sayfaya gidilmiyorsa genel paylaşım bekliyor mu diye kontrol et
    if (!isGoingToSharedPreview) {
      final hasShare = await _checkPendingShare();
      if (hasShare && isLoggedIn) return '/upload_file';
    }

    return null; // Rotaya izin ver ve yolu kesme
  }

  Future<bool> _checkPendingShare() async {
    if (isDesktopOS) return false;
    try {
      final bool? hasShare = await _platform.invokeMethod('hasPendingShare');
      return hasShare ?? false;
    } on PlatformException {
      return false;
    } catch (e) {
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
// 🖥️ MASAÜSTÜ ARAYÜZÜ: Windows Explorer / MacOS Tarzı Yan Menü
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
          Container(
            width: 190,
            color: ThemeColors.sidePanelColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
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
                          size: 24,
                          color: ThemeColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Mostromo",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildNavItem(
                  context,
                  0,
                  Icons.folder_outlined,
                  Icons.folder,
                  'Dosyalarım',
                ),
                _buildNavItem(
                  context,
                  1,
                  Icons.search_rounded,
                  Icons.search_rounded,
                  'Ara',
                ),
                _buildNavItem(
                  context,
                  2,
                  Icons.delete_outline_rounded,
                  Icons.delete_rounded,
                  'Geri Dönüşüm',
                ),
                _buildNavItem(
                  context,
                  3,
                  Icons.podcasts_rounded,
                  Icons.podcasts_rounded,
                  'Paylaşılanlar',
                ),

                const Spacer(),

                if (isDesktopOS) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      bottom: 8,
                      top: 16,
                    ),
                    child: Text(
                      "SİSTEM",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.captionText.withOpacity(0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildNavItem(
                    context,
                    5,
                    Icons.business_center_outlined,
                    Icons.business_center,
                    'Workspaces',
                  ),
                  _buildNavItem(
                    context,
                    4,
                    Icons.cloud_upload_outlined,
                    Icons.cloud_upload,
                    'Yükle',
                  ),
                ],

                _buildNavItem(
                  context,
                  isDesktopOS ? 6 : 4,
                  Icons.settings_outlined,
                  Icons.settings,
                  'Ayarlar',
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          Container(width: 1, color: Colors.grey.withOpacity(0.15)),
          Expanded(child: ClipRRect(child: navigationShell)),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final bool isSelected = navigationShell.currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: ThemeColors.primary.withOpacity(0.05),
          onTap: () {
            if (index == navigationShell.currentIndex) {
              context.read<NavEventProvider>().notifyDoubleTap(index);
            } else {
              context.read<StorageViewModel>().clearSelection();
              context.read<StorageViewModel>().closeInfoPanel();
              navigationShell.goBranch(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 20,
                  color: isSelected
                      ? ThemeColors.primary
                      : ThemeColors.captionText,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? ThemeColors.primary
                        : ThemeColors.titleText.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 📱 MOBİL ARAYÜZ
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

  int _getBottomBarIndex(int branchIndex) {
    if (branchIndex == 0) return 0; // Dosyalar
    if (branchIndex == 1) return 1; // Ara
    if (branchIndex == 3) return 2; // Paylaşılanlar
    if (branchIndex == 2 || branchIndex == 4) return 3; // Menü (Ayarlar & Çöp)
    return 0;
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: ThemeColors.floatingPanelColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeColors.captionText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  title: Text(
                    "Geri Dönüşüm Kutusu",
                    style: TextStyle(
                      color: ThemeColors.titleText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ThemeColors.captionText,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.navigationShell.goBranch(2);
                  },
                ),
                const SizedBox(height: 8),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: ThemeColors.primary,
                    ),
                  ),
                  title: Text(
                    "Ayarlar",
                    style: TextStyle(
                      color: ThemeColors.titleText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ThemeColors.captionText,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.navigationShell.goBranch(4);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isStoragePage = widget.navigationShell.currentIndex == 0;
    final bool shouldShowBar = isStoragePage ? _isVisible : true;

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double totalBarHeight = 80.0 + bottomPadding;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!isStoragePage || notification is! ScrollUpdateNotification)
            return false;

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
                indicatorColor: ThemeColors.primary.withValues(alpha: 0.15),
                selectedIndex: _getBottomBarIndex(
                  widget.navigationShell.currentIndex,
                ),
                onDestinationSelected: (index) {
                  if (index == 3) {
                    _showMobileMenu(context);
                    return;
                  }

                  int targetBranch = 0;
                  if (index == 0) targetBranch = 0;
                  if (index == 1) targetBranch = 1;
                  if (index == 2) targetBranch = 3;

                  if (targetBranch == widget.navigationShell.currentIndex) {
                    context.read<NavEventProvider>().notifyDoubleTap(
                      targetBranch,
                    );
                  } else {
                    context.read<StorageViewModel>().clearSelection();
                    context.read<StorageViewModel>().closeInfoPanel();
                    widget.navigationShell.goBranch(targetBranch);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: 'Dosyalar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: 'Ara',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.podcasts_rounded),
                    selectedIcon: Icon(Icons.podcasts_rounded),
                    label: 'Paylaşılan',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    selectedIcon: Icon(Icons.menu_open_rounded),
                    label: 'Menü',
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
