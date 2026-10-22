import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/tts_config.dart';
import 'core/layout/adaptive_layout.dart';
import 'core/layout/zest_sidebar.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/app_user.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/services/google_auth_service.dart';
import 'features/categories/services/categories_service.dart';
import 'features/home/pages/home_page.dart';
import 'features/profile/pages/profile_page.dart';
import 'features/progress/services/xp_store.dart';
import 'features/settings/pages/settings_page.dart';
import 'features/settings/services/settings_store.dart';
import 'features/tts/services/asset_tts_service.dart';
import 'features/tts/services/tts_service.dart';
import 'features/tts/services/voicevox_tts_service.dart';
import 'features/users/services/api_user_repo.dart';
import 'features/users/services/progress_sync.dart';
import 'features/users/services/user_session.dart';
import 'features/videos/services/video_progress_store.dart';
import 'features/videos/services/videos_service.dart';
import 'features/vocab/services/srs_store.dart';
import 'features/vocab/services/vocab_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDotEnv();
  final prefs = await SharedPreferences.getInstance();

  final client = ApiClient();
  final repo = ApiUserRepo(client);
  final session = UserSession(
    repo: repo,
    prefs: prefs,
    auth: GoogleAuthService(),
    getCategories: () async =>
        (await CategoriesService(client).getCategories()).map((c) => c.name),
  );
  // Restore sesi TIDAK di-await di sini: frame pertama harus segera muncul
  // (LoginPage), sementara prompt Google + hydrate backend jalan di belakang.
  // Jika user sudah login, ValueListenableBuilder di ZestRoot berpindah ke Home
  // begitu restore selesai. restore() tidak pernah melempar.
  // onUnauthorized dipasang duluan supaya 401 pertama (jalur sesi tersimpan
  // maupun prompt) selalu menemukan handler.
  client.onUnauthorized = session.reauthenticate;
  unawaited(session.restore());

  final tts = TtsConfig.baseUrl.isNotEmpty
      ? VoicevoxTtsService() as TtsService
      : AssetTtsService() as TtsService;

  runApp(
    ZestRoot(
      prefs: prefs,
      session: session,
      categoriesService: CategoriesService(client),
      vocabService: VocabService(client),
      videosService: VideosService(client),
      tts: tts,
    ),
  );
}

/// Muat `.env` sebagai asset. Kegagalan di sini tidak boleh mematikan aplikasi:
/// `flutter_dotenv` melempar `FileNotFoundError` saat file tidak ada (mis. clone
/// baru tanpa menyalin `.env.example`), dan `rootBundle` juga tidak punya file itu
/// di platform yang tidak mem-bundle asset. Tanpa guard, aplikasi crash sebelum
/// `runApp` dan tidak ada UI sama sekali untuk menjelaskan penyebabnya.
Future<void> loadDotEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('loadDotEnv(): .env tidak terbaca ($error).');
  }
}

/// Akar aplikasi: menahan LoginPage sampai [UserSession] punya user.
class ZestRoot extends StatelessWidget {
  const ZestRoot({
    super.key,
    required this.prefs,
    required this.session,
    required this.categoriesService,
    required this.vocabService,
    required this.videosService,
    this.tts,
  });

  final SharedPreferences prefs;
  final UserSession session;
  final CategoriesService categoriesService;
  final VocabService vocabService;
  final VideosService videosService;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark();
    return ValueListenableBuilder<AppUser?>(
      valueListenable: session,
      builder: (context, user, _) {
        if (user == null) {
          return MaterialApp(
            title: 'Zest',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: LoginPage(session: session),
          );
        }

        final uid = user.uid;
        final repo = session.repo;
        final settings = SettingsStore(prefs, uid);
        settings.load();
        return ZestApp(
          key: ValueKey(uid),
          user: user,
          sync: ProgressSync(uid, repo, prefs),
          onLogout: () => session.logout(),
          categoriesService: categoriesService,
          vocabService: vocabService,
          videosService: videosService,
          srsStore: SrsStore(prefs, uid),
          xpStore: XpStore(prefs, uid),
          videoProgressStore: VideoProgressStore(prefs, uid),
          settings: settings,
          tts: tts,
        );
      },
    );
  }
}

class ZestApp extends StatelessWidget {
  const ZestApp({
    super.key,
    required this.categoriesService,
    required this.vocabService,
    required this.videosService,
    required this.srsStore,
    required this.xpStore,
    required this.videoProgressStore,
    this.user,
    this.sync,
    this.settings,
    this.onLogout,
    this.tts,
  });

  final CategoriesService categoriesService;
  final VocabService vocabService;
  final VideosService videosService;
  final SrsStore srsStore;
  final XpStore xpStore;
  final VideoProgressStore videoProgressStore;
  final AppUser? user;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final VoidCallback? onLogout;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    Widget home = AppShell(
      user: user,
      sync: sync,
      onLogout: onLogout,
      categoriesService: categoriesService,
      vocabService: vocabService,
      videosService: videosService,
      srsStore: srsStore,
      xpStore: xpStore,
      videoProgressStore: videoProgressStore,
      settings: settings,
      tts: tts,
    );

    return MaterialApp(
      title: 'Zest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: home,
    );
  }
}

/// Shell utama setelah login: navigasi bawah dua tab, Beranda (dashboard)
/// dan Profil. State tiap tab dijaga via [IndexedStack].
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.categoriesService,
    required this.vocabService,
    required this.videosService,
    required this.srsStore,
    required this.xpStore,
    required this.videoProgressStore,
    required this.onLogout,
    this.user,
    this.sync,
    this.settings,
    this.tts,
  });

  final CategoriesService categoriesService;
  final VocabService vocabService;
  final VideosService videosService;
  final SrsStore srsStore;
  final XpStore xpStore;
  final VideoProgressStore videoProgressStore;
  final VoidCallback? onLogout;
  final AppUser? user;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final TtsService? tts;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  final List<int> _syncOnTab = const [1];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Amankan progres lokal saat app dipindahkan ke latar.
      widget.sync?.flush();
    }
  }

  void _setTab(int index) {
    setState(() => _index = index);
    if (_syncOnTab.contains(index)) widget.sync?.flush();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final body = IndexedStack(
      index: _index,
      children: [
        HomePage(
          categoriesService: widget.categoriesService,
          vocabService: widget.vocabService,
          srsStore: widget.srsStore,
          xpStore: widget.xpStore,
          videosService: widget.videosService,
          videoProgressStore: widget.videoProgressStore,
          user: user,
          sync: widget.sync,
          settings: widget.settings,
          onOpenProfile: () => _setTab(1),
          tts: widget.tts,
        ),
        if (user != null)
          ProfilePage(
            user: user,
            categoriesService: widget.categoriesService,
            srsStore: widget.srsStore,
            xpStore: widget.xpStore,
            videoProgressStore: widget.videoProgressStore,
            sync: widget.sync,
            settings: widget.settings,
            onLogout: widget.onLogout ?? () {},
          )
        else
          const SizedBox.shrink(),
        if (widget.settings != null)
          SettingsPage(settings: widget.settings!, tts: widget.tts)
        else
          const SizedBox.shrink(),
      ],
    );

    if (AdaptiveLayout.isWide(context)) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZestSidebar(
              user: user,
              selectedIndex: _index,
              onSelect: _setTab,
              sync: widget.sync,
              showSettings: widget.settings != null,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: user == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: NavigationBar(
                backgroundColor: AppColors.bg,
                indicatorColor: AppColors.accent.withValues(alpha: 0.16),
                selectedIndex: _index,
                onDestinationSelected: _setTab,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Beranda',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profil',
                  ),
                  if (widget.settings != null)
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Pengaturan',
                    ),
                ],
              ),
            ),
    );
  }
}
