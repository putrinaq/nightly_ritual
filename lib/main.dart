import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/habits_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/rituals_page.dart';
import 'ritual/ritual_flow.dart';
import 'services/auth_service.dart';
import 'services/moon_phase_service.dart';
import 'services/notification_service.dart';
import 'services/ritual_storage_service.dart';
import 'services/spotify_service.dart';
import 'theme/app_theme.dart';
import 'widgets/night_sky.dart';
import 'widgets/shell.dart';

String _platformAppId() {
  if (kIsWeb) return dotenv.maybeGet('FIREBASE_APP_ID_WEB') ?? '';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return dotenv.maybeGet('FIREBASE_APP_ID_IOS') ?? '';
    default:
      return dotenv.maybeGet('FIREBASE_APP_ID_ANDROID') ?? '';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  // isOptional: a missing .env (e.g. on web, where it isn't served) used to
  // leave dotenv uninitialised, and the next dotenv.env read threw.
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    debugPrint('.env failed to load: $e');
    dotenv.testLoad();
  }

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.maybeGet('FIREBASE_API_KEY') ?? '',
      appId: _platformAppId(),
      messagingSenderId: dotenv.maybeGet('FIREBASE_MESSAGING_SENDER_ID') ?? '',
      projectId: dotenv.maybeGet('FIREBASE_PROJECT_ID') ?? '',
      storageBucket: dotenv.maybeGet('FIREBASE_STORAGE_BUCKET'),
      authDomain: dotenv.maybeGet('FIREBASE_AUTH_DOMAIN'),
    ),
  );
  AuthService().init();

  final storageService = RitualStorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();

  await SpotifyService().init();

  final prefs = await SharedPreferences.getInstance();
  final reminderPrefs = ReminderPreferences(prefs);
  if (reminderPrefs.isEnabled) {
    await notificationService.scheduleReminderAt(reminderPrefs.hour, reminderPrefs.minute);
  }

  runApp(NightlyRitualApp(
    storageService: storageService,
    notificationService: notificationService,
    reminderPrefs: reminderPrefs,
  ));
}

class NightlyRitualApp extends StatelessWidget {
  final RitualStorageService storageService;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;

  const NightlyRitualApp({
    super.key,
    required this.storageService,
    required this.notificationService,
    required this.reminderPrefs,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nightly Ritual',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: MainScreen(
        storageService: storageService,
        notificationService: notificationService,
        reminderPrefs: reminderPrefs,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final RitualStorageService storageService;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;

  const MainScreen({
    super.key,
    required this.storageService,
    required this.notificationService,
    required this.reminderPrefs,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const _tabs = [
    NavItem('Tonight', Icons.nightlight_outlined, Icons.nightlight_round),
    NavItem('Intentions', Icons.auto_awesome_outlined, Icons.auto_awesome),
    NavItem('Habits', Icons.check_circle_outline_rounded, Icons.check_circle_rounded),
    NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  // One subscription for the screen's lifetime. The old code called
  // authStateChanges() inside build(), so every setState (e.g. switching
  // tabs) resubscribed, briefly reported "waiting", and swapped the whole
  // tab stack for a spinner.
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool _authResolved = false;

  bool _inRitual = false;
  int _tab = 0;
  Timer? _midnight;

  late int _streak;
  late int _total;
  late bool _doneToday;
  late String? _lastRitual;
  late MoonPhaseInfo _moon;

  RitualStorageService get _storage => widget.storageService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocal();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    _scheduleMidnightRefresh();
  }

  Future<void> _onAuth(User? user) async {
    if (user != null) await _storage.useAccount(user.uid);
    if (!mounted) return;
    setState(() {
      if (user?.uid != _user?.uid) {
        _inRitual = false;
        _tab = 0;
      }
      _user = user;
      _authResolved = true;
      _loadLocal();
    });
  }

  void _loadLocal() {
    _streak = _storage.getStreakDays();
    _total = _storage.getTotalRituals();
    _doneToday = _storage.isRitualCompletedToday();
    _lastRitual = _storage.getLastRitualDate();
    _moon = MoonPhaseService.getCurrentMoonPhase();
  }

  /// "Done tonight", the streak and the moon all depend on the date, so
  /// refresh them when the day rolls over or the app comes back.
  void _scheduleMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(_loadLocal);
      _scheduleMidnightRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_loadLocal);
      _scheduleMidnightRefresh();
    }
  }

  Future<int> _completeRitual() async {
    await _storage.completeRitual();
    if (mounted) setState(_loadLocal);
    return _storage.getStreakDays();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _midnight?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final showNav = user != null && !_inRitual;
    const navClearance = FloatingNavBar.height + FloatingNavBar.gap * 2;

    final Widget content;
    if (!_authResolved) {
      content = const SizedBox.shrink(key: ValueKey('boot'));
    } else if (user == null) {
      content = const LoginPage(key: ValueKey('login'));
    } else if (_inRitual) {
      content = RitualFlow(
        key: const ValueKey('ritual'),
        uid: user.uid,
        moon: _moon,
        onComplete: _completeRitual,
        onExit: () => setState(() => _inRitual = false),
      );
    } else {
      content = TabStack(
        key: ValueKey('tabs-${user.uid}'),
        index: _tab,
        children: [
          HomePage(
            streakDays: _streak,
            totalRituals: _total,
            todayRitualCompleted: _doneToday,
            lastRitualDate: _lastRitual,
            moonPhase: _moon,
            notificationService: widget.notificationService,
            reminderPrefs: widget.reminderPrefs,
            user: user,
            onBegin: () => setState(() => _inRitual = true),
          ),
          RitualsPage(user: user),
          HabitsPage(user: user),
          ProfilePage(user: user, streakDays: _streak, totalRituals: _total),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.ink,
      resizeToAvoidBottomInset: false,
      body: ShellInsets(
        bottom: showNav ? safeBottom + navClearance : safeBottom,
        nav: showNav ? navClearance : 0,
        child: Stack(
          children: [
            const Positioned.fill(child: NightSky()),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Motion.slow,
                reverseDuration: Motion.base,
                switchInCurve: Motion.easeOut,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.98, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: content,
              ),
            ),
            // Scroll edge: content dissolves under the status bar instead
            // of being cut off by it.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + 20,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xF00C0F19), Color(0x000C0F19)],
                      stops: [0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: safeBottom + FloatingNavBar.gap,
              child: IgnorePointer(
                ignoring: !showNav,
                child: AnimatedSlide(
                  offset: showNav ? Offset.zero : const Offset(0, 1.6),
                  duration: Motion.slow,
                  curve: Motion.easeOut,
                  child: AnimatedOpacity(
                    opacity: showNav ? 1 : 0,
                    duration: Motion.base,
                    child: FloatingNavBar(
                      items: _tabs,
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
