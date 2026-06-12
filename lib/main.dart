// lib/main.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mostromo_connect/features/storage/services/local_bridge_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:app_links/app_links.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

// Ortak paketlerden gelenler
import 'package:common_ui/data/themes.dart';
import 'package:shared_core/data/notifiers.dart';

// Masaüstü Pencere ve Görev Çubuğu Yöneticileri
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

// Uygulama içi importlar
import 'core/app_router.dart';
import 'core/nav_event_provider.dart';
import 'features/storage/viewmodels/storage_view_model.dart';
import 'core/auth_view_model.dart';

// ==========================================================
// 🌟 WINDOWS İÇİN REGISTRY (KAYIT DEFTERİ) PROTOKOL YAZICI
// ==========================================================
void _registerWindowsProtocol() {
  if (!Platform.isWindows) return;
  try {
    final executable = Platform.resolvedExecutable;
    Process.runSync('reg', [
      'add',
      'HKCU\\Software\\Classes\\mostromo',
      '/ve',
      '/d',
      'URL:mostromo Protocol',
      '/f',
    ]);
    Process.runSync('reg', [
      'add',
      'HKCU\\Software\\Classes\\mostromo',
      '/v',
      'URL Protocol',
      '/d',
      '',
      '/f',
    ]);
    Process.runSync('reg', [
      'add',
      'HKCU\\Software\\Classes\\mostromo\\shell\\open\\command',
      '/ve',
      '/d',
      '"$executable" "%1"',
      '/f',
    ]);
  } catch (e) {
    debugPrint("Windows protokol kaydı hatası: $e");
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final authViewModel = AuthViewModel();
  final storageViewModel = StorageViewModel();
  final appRouter = AppRouter(authViewModel);

  // --- MASAÜSTÜ (WINDOWS) AYARLARI ---
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    _registerWindowsProtocol();

    // 🌟 WINDOWS İKİNCİ PENCERE YAKALAYICISI (GÜNCELLENDİ)
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "mostromo_connect_instance",
      onSecondWindow: (newArgs) {
        if (newArgs.isNotEmpty) {
          final link = newArgs.first;
          final uri = Uri.tryParse(link);

          // Yeni host 'connect' veya eski host 'shared' desteği
          if (uri != null &&
              uri.scheme == 'mostromo' &&
              (uri.host == 'connect' || uri.host == 'shared')) {
            // Parametre adı 'token' veya 't' olabilir
            final token =
                uri.queryParameters['token'] ?? uri.queryParameters['t'];
            if (token != null && token.isNotEmpty) {
              appRouter.router.push('/shared_preview?token=$token');
            }
          }
        }
        windowManager.show();
        windowManager.focus();
      },
    );

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "Mostromo Connect",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });

    final localBridgeServer = LocalBridgeServer(
      storageViewModel: storageViewModel,
    );
    await localBridgeServer.start();
  }

  // --- DOWNLOADER BAŞLATMA (ANDROID/IOS) ---
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FlutterDownloader.initialize(debug: true);
  }

  await loadSelectedTheme();
  initThemeListener();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authViewModel),
        ChangeNotifierProvider.value(value: storageViewModel),
        ChangeNotifierProvider(create: (_) => NavEventProvider()),
      ],
      child: MyApp(appRouter: appRouter),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AppRouter appRouter;

  const MyApp({super.key, required this.appRouter});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initSystemTray();
    }
    _initDeepLinks();
  }

  // ==========================================================
  // 🔗 DEEP LINK (PAYLAŞIM LİNKİ) DİNLEYİCİSİ (GÜNCELLENDİ)
  // ==========================================================
  void _initDeepLinks() {
    _appLinks = AppLinks();

    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) _handleIncomingLink(uri);
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });
  }

  void _handleIncomingLink(Uri uri) {
    // 🌟 Yeni 'connect' host'u ve 'token' parametresi kontrol ediliyor
    if (uri.scheme == 'mostromo' &&
        (uri.host == 'connect' || uri.host == 'shared')) {
      final token = uri.queryParameters['token'] ?? uri.queryParameters['t'];

      if (token != null && token.isNotEmpty) {
        debugPrint("🔗 Paylaşılan dosya linki algılandı! Token: $token");

        if (_isDesktop) {
          windowManager.show();
          windowManager.focus();
        }

        // Kullanıcıyı önizleme sayfasına fırlat
        widget.appRouter.router.push('/shared_preview?token=$token');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    await trayManager.setIcon('assets/app_icon.ico');
    await trayManager.setToolTip('Mostromo Connect');
    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_app', label: 'Mostromo\'yu Aç'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Tamamen Çıkış Yap'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTheme,
      builder: (context, themeId, _) {
        ThemeData baseTheme =
            appThemes[themeId.clamp(0, appThemes.length - 1)].data;

        if (_isDesktop) {
          baseTheme = baseTheme.copyWith(
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.grey.withValues(alpha: 0.05),
          );
        }

        baseTheme = baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Inter'),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: 'Inter',
          ),
        );

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Mostromo Connect',
          theme: baseTheme,
          routerConfig: widget.appRouter.router,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr', ''), Locale('en', '')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
