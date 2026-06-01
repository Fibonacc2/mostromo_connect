import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb kontrolü için
import 'package:mostromo_connect/features/storage/services/local_bridge_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

// Ortak paketlerden gelenler
import 'package:common_ui/data/themes.dart';
import 'package:shared_core/data/notifiers.dart';

// 🌟 YENİ: Masaüstü Pencere ve Görev Çubuğu Yöneticileri
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

// Uygulama içi importlar
import 'core/app_router.dart';
import 'core/nav_event_provider.dart';
import 'features/storage/viewmodels/storage_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ VİEWMODEL'İ ÖNCEDEN OLUŞTURUYORUZ
  final storageViewModel = StorageViewModel();

  // --- MASAÜSTÜ (WINDOWS) AYARLARI VE YEREL SUNUCU ---
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800), // Başlangıç boyutu
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "Mostromo Connect",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();

      // 🌟 SİHİRLİ DOKUNUŞ: Çarpıya (X) basıldığında uygulamanın kapanmasını engelle!
      await windowManager.setPreventClose(true);
    });

    // Local Bridge'i başlat (VS Code'u dinleyen arka plan servisi)
    final localBridgeServer = LocalBridgeServer(
      storageViewModel: storageViewModel,
    );
    await localBridgeServer.start();
  }

  // --- DOWNLOADER BAŞLATMA (ANDROID/IOS) ---
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FlutterDownloader.initialize(debug: true);
  }

  // Tema yükleme (Ortak)
  await loadSelectedTheme();
  initThemeListener();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageViewModel),
        ChangeNotifierProvider(create: (_) => NavEventProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// 🌟 WIDGET'I STATEFUL YAPIYORUZ (Tray ve Window dinleyicileri için)
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// WindowListener ve TrayListener (Mixins) ekleniyor
class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  // Masaüstü platform kontrolü için güvenli bir getter
  bool get _isDesktop {
    if (kIsWeb) return false; // Web ise false
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    // 🌟 SADECE WINDOWS'TA DİNLEYİCİLERİ AKTİF ET (Android'i korur)
    if (_isDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initSystemTray();
    }
  }

  @override
  void dispose() {
    // 🌟 SADECE WINDOWS'TA DİNLEYİCİLERİ KALDIR
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  // ==========================================================
  // 🌟 SYSTEM TRAY (GÖREV ÇUBUĞU) KURULUMU
  // ==========================================================
  Future<void> _initSystemTray() async {
    // Windows için uygulamanın assets klasöründe app_icon.ico olmalı
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

  // ==========================================================
  // 🌟 PENCERE OLAYLARI
  // ==========================================================
  @override
  void onWindowClose() async {
    // Çarpıya (X) basıldığında tetiklenir
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // Uygulamayı kapatma, sadece görünmez yap! (Arkada çalışmaya devam eder)
      windowManager.hide();
    }
  }

  // ==========================================================
  // 🌟 TRAY (SAĞ ALT İKON) OLAYLARI
  // ==========================================================
  @override
  void onTrayIconMouseDown() {
    // Sağ alttaki ikona sol tıklandığında pencereyi geri getir
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // İkona sağ tıklandığında menüyü aç
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      // "Tamamen Çıkış Yap" denirse zorla kapat
      windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedTheme,
      builder: (context, themeId, _) {
        // Geçerli temayı seçiyoruz
        ThemeData baseTheme =
            appThemes[themeId.clamp(0, appThemes.length - 1)].data;

        // EĞER MASAÜSTÜ/WINDOWS İSE: Android tıklama efektini tamamen yok et
        if (_isDesktop) {
          baseTheme = baseTheme.copyWith(
            splashFactory:
                NoSplash.splashFactory, // Dalgalanmayı (ripple) kapatır
            splashColor: Colors.transparent, // Tıklama sıçrama rengi şeffaf
            highlightColor: Colors.transparent, // Basılı tutma rengi şeffaf
            hoverColor: Colors.grey.withOpacity(
              0.05,
            ), // Çok hafif, zarif fare üzeri efekti
          );
        }

        baseTheme = baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: 'Montserrat'),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: 'Montserrat',
          ),
        );

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Mostromo Connect',
          theme: baseTheme,
          routerConfig: AppRouter().router,
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
