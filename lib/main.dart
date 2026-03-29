import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ritual_storage_service.dart';
import 'services/spotify_service.dart';
import 'services/moon_phase_service.dart';
import 'services/notification_service.dart';
import 'widgets/moon_phase_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF030303),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize storage service
  final storageService = RitualStorageService();
  await storageService.init();

  // Initialize Spotify service
  final spotifyService = SpotifyService(storageService);
  await spotifyService.init();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.init();

  // Get shared preferences for reminder settings
  final prefs = await SharedPreferences.getInstance();
  final reminderPrefs = ReminderPreferences(prefs);

  // Reschedule reminder if it was enabled (clears on device reboot or app update)
  if (reminderPrefs.isEnabled) {
    await notificationService.scheduleReminderAt(
        reminderPrefs.hour, reminderPrefs.minute);
  }

  runApp(NightlyRitualApp(
    storageService: storageService,
    spotifyService: spotifyService,
    notificationService: notificationService,
    reminderPrefs: reminderPrefs,
  ));
}

class NightlyRitualApp extends StatelessWidget {
  final RitualStorageService storageService;
  final SpotifyService spotifyService;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;

  const NightlyRitualApp({
    super.key,
    required this.storageService,
    required this.spotifyService,
    required this.notificationService,
    required this.reminderPrefs,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nightly Ritual',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030303),
        primaryColor: const Color(0xFFA855F7), // Purple 500
        fontFamily: 'Inter', // Assumes system sans-serif if not available
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA855F7),
          surface: Color(0xFF0A0A0A),
          onSurface: Color(0xFFEDEDED),
        ),
      ),
      home: MainScreen(
        storageService: storageService,
        spotifyService: spotifyService,
        notificationService: notificationService,
        reminderPrefs: reminderPrefs,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final RitualStorageService storageService;
  final SpotifyService spotifyService;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;

  const MainScreen({
    super.key,
    required this.storageService,
    required this.spotifyService,
    required this.notificationService,
    required this.reminderPrefs,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isAuthenticated = false;
  bool isRitualInProgress = false;
  late int streakDays;
  late int totalRituals;
  late bool todayRitualCompleted;
  late MoonPhaseInfo moonPhase;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    streakDays = widget.storageService.getStreakDays();
    totalRituals = widget.storageService.getTotalRituals();
    todayRitualCompleted = widget.storageService.isRitualCompletedToday();
    moonPhase = MoonPhaseService.getCurrentMoonPhase();
  }

  void _handleLogin() {
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() => isAuthenticated = true);
    });
  }

  Future<void> _handleRitualComplete() async {
    await widget.storageService.completeRitual();
    setState(() {
      isRitualInProgress = false;
      _loadData(); // Reload all data
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: Stack(
        children: [
          // Background Layer
          const Positioned.fill(child: StarryBackground()),

          // Content Layer
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: !isAuthenticated
                  ? LoginPage(onLogin: _handleLogin)
                  : isRitualInProgress
                      ? RitualFlow(
                          onComplete: _handleRitualComplete,
                          onExit: () =>
                              setState(() => isRitualInProgress = false),
                          spotifyService: widget.spotifyService,
                          storageService: widget.storageService,
                        )
                      : HomePage(
                          streakDays: streakDays,
                          totalRituals: totalRituals,
                          todayRitualCompleted: todayRitualCompleted,
                          moonPhase: moonPhase,
                          spotifyService: widget.spotifyService,
                          notificationService: widget.notificationService,
                          reminderPrefs: widget.reminderPrefs,
                          storageService: widget.storageService,
                          onBegin: () =>
                              setState(() => isRitualInProgress = true),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS: Background & Visuals
// -----------------------------------------------------------------------------

class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];
  final List<_ShootingStar> _shootingStars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Arbitrary long duration for loop
    )..repeat();
    _initStars();
  }

  void _initStars() {
    for (int i = 0; i < 150; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 1.5 + 0.5,
        opacity: _random.nextDouble() * 0.8 + 0.2,
        speed: _random.nextDouble() * 0.5 + 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Shooting star logic
        if (_random.nextDouble() < 0.01) {
          _shootingStars.add(_ShootingStar(
            x: _random.nextDouble(), // 0.0 to 1.0 (screen width)
            y: _random.nextDouble() * 0.3, // Top 30% of screen
            angle: math.pi / 4 + (_random.nextDouble() * 0.1),
            speed: 0.01 + _random.nextDouble() * 0.01,
            length: 0.1 + _random.nextDouble() * 0.05,
          ));
        }

        // Remove dead shooting stars
        _shootingStars.removeWhere((s) => s.life <= 0);

        return CustomPaint(
          painter: StarryPainter(
            stars: _stars,
            shootingStars: _shootingStars,
            time: _controller.value, // Just to trigger repaint
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Star {
  double x, y, size, opacity, speed;
  _Star(
      {required this.x,
      required this.y,
      required this.size,
      required this.opacity,
      required this.speed});
}

class _ShootingStar {
  double x, y, angle, speed, length;
  double life = 1.0;
  _ShootingStar(
      {required this.x,
      required this.y,
      required this.angle,
      required this.speed,
      required this.length});
}

class StarryPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_ShootingStar> shootingStars;
  final double time;

  StarryPainter(
      {required this.stars, required this.shootingStars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Gradients
    final Paint bgPaint = Paint()..color = const Color(0xFF030303);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final Paint purpleGrad = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7832C8).withValues(alpha: 0.07),
          Colors.transparent
        ],
        radius: 0.8,
        center: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), purpleGrad);

    final Paint blueGrad = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3264FF).withValues(alpha: 0.05),
          Colors.transparent
        ],
        radius: 0.8,
        center: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), blueGrad);

    // 2. Stars
    for (var star in stars) {
      final double flicker = math.sin(
              DateTime.now().millisecondsSinceEpoch * 0.001 * star.speed * 5) *
          0.2;
      final double currentOpacity = (star.opacity + flicker).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(star.x * w, star.y * h), star.size, paint);
    }

    // 3. Shooting Stars
    for (var s in shootingStars) {
      final startX = s.x * w;
      final startY = s.y * h;
      // Calculate end point based on angle (roughly 45 deg)
      final endX =
          startX - (math.cos(s.angle) * s.length * w); // Trail goes back
      final endY = startY - (math.sin(s.angle) * s.length * h);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: s.life), Colors.transparent],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ).createShader(
            Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)))
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

      // Update position
      s.x += math.cos(s.angle) * s.speed;
      s.y += math.sin(s.angle) * s.speed;
      s.life -= 0.02;
    }
  }

  @override
  bool shouldRepaint(covariant StarryPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// COMPONENTS: Pages
// -----------------------------------------------------------------------------

class LoginPage extends StatelessWidget {
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: 0.00, // Slight tilt
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Ritual',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Text(
            'Linear-style Manifestation',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          CupertinoButton(
            onPressed: onLogin,
            padding: EdgeInsets.zero,
            child: Container(
              width: 280,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Connect Account',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final int streakDays;
  final int totalRituals;
  final bool todayRitualCompleted;
  final MoonPhaseInfo moonPhase;
  final SpotifyService spotifyService;
  final NotificationService notificationService;
  final ReminderPreferences reminderPrefs;
  final RitualStorageService storageService;
  final VoidCallback onBegin;

  const HomePage({
    super.key,
    required this.streakDays,
    required this.totalRituals,
    required this.todayRitualCompleted,
    required this.moonPhase,
    required this.spotifyService,
    required this.notificationService,
    required this.reminderPrefs,
    required this.storageService,
    required this.onBegin,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _reminderEnabled = widget.reminderPrefs.isEnabled;
    _reminderTime = widget.reminderPrefs.timeOfDay;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Header with dynamic moon phase
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  MoonPhaseIcon(
                    phase: widget.moonPhase.phase,
                    size: 28,
                    color: const Color(0xFFE9D5FF),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.moonPhase.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Illumination ${widget.moonPhase.illuminationPercent}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              // Spotify connection indicator
              GestureDetector(
                onTap: () => _showSpotifyOptions(context),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.spotifyService.isConnected
                        ? const Color(0xFF1DB954) // Spotify green
                        : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: (widget.spotifyService.isConnected
                                  ? const Color(0xFF1DB954)
                                  : Colors.redAccent)
                              .withValues(alpha: 0.5),
                          blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            _getGreeting(),
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white),
          ),
          const SizedBox(height: 32),
          // Bento Grid with dynamic data
          Row(
            children: [
              Expanded(
                child: _BentoCard(
                  icon: Icons.local_fire_department,
                  value: '${widget.streakDays}',
                  label: 'Day Streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BentoCard(
                  icon: Icons.auto_awesome,
                  value: '${widget.totalRituals}',
                  label: 'Spells Cast',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Spotify Playlist Card
          GestureDetector(
            onTap: () => widget.spotifyService.openSpotifyPlaylist(),
            child: Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      color: Color(0xFF1DB954),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ritual Playlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Open in Spotify',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Reminder Card
          GestureDetector(
            onTap: () => _showReminderSettings(context),
            child: Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFA855F7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Reminder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _reminderEnabled
                              ? 'Set for ${widget.reminderPrefs.timeFormatted}'
                              : 'Tap to set a reminder',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _reminderEnabled
                          ? const Color(0xFF22C55E)
                          : Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // Affirmations card
          GestureDetector(
            onTap: () => _showManageAffirmations(context),
            child: Container(
              height: 64,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Affirmations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          () {
                            final count = widget.storageService
                                .getCustomAffirmations()
                                .length;
                            return count > 0
                                ? '$count custom · tap to manage'
                                : 'Tap to add your own';
                          }(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Main Ritual Card - always tappable
          GestureDetector(
            onTap: widget.onBegin,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Gradient Background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF312E81).withValues(alpha: 0.4),
                            Colors.black,
                            const Color(0xFF581C87).withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Floating Moon
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Transform.rotate(
                      angle: 0.2,
                      child: Icon(
                        CupertinoIcons.moon,
                        size: 180,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _GlassIcon(icon: Icons.auto_awesome_outlined),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.todayRitualCompleted
                                    ? const Color(0xFF22C55E)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFFA855F7)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: widget.todayRitualCompleted
                                        ? const Color(0xFF22C55E)
                                            .withValues(alpha: 0.3)
                                        : const Color(0xFFA855F7)
                                            .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: widget.todayRitualCompleted
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFD8B4FE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.todayRitualCompleted
                                        ? 'SEALED'
                                        : 'READY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: widget.todayRitualCompleted
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFD8B4FE),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.todayRitualCompleted
                              ? 'Repeat Ritual'
                              : 'Begin Nightly Ritual',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.todayRitualCompleted
                              ? 'Tap to strengthen your manifestation'
                              : MoonPhaseService.getRitualMeaning(
                                  widget.moonPhase.phase),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _affirmationCategories = [
    'Obsession',
    'Detachment',
    'Glow Up',
    'Road Opener',
    'Custom',
  ];

  void _showManageAffirmations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final custom = widget.storageService.getCustomAffirmations();
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.format_quote_rounded,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Affirmations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Add button
                        GestureDetector(
                          onTap: () => _showAddAffirmationDialog(
                              context, setModalState),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add,
                                    color: Color(0xFF6366F1), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: [
                        // Built-in section
                        Text(
                          'BUILT-IN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._AffirmationStepState._defaultAffirmations
                            .map((a) => _affirmationTile(
                                  text: a['text'] as String,
                                  cat: a['cat'] as String,
                                  canEdit: false,
                                  onEdit: null,
                                  onDelete: null,
                                )),
                        if (custom.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'CUSTOM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...custom.asMap().entries.map((entry) =>
                              _affirmationTile(
                                text: entry.value['text']!,
                                cat: entry.value['cat']!,
                                canEdit: true,
                                onEdit: () => _showEditAffirmationDialog(
                                  context,
                                  setModalState,
                                  index: entry.key,
                                  initialText: entry.value['text']!,
                                  initialCat: entry.value['cat']!,
                                ),
                                onDelete: () async {
                                  final updated =
                                      List<Map<String, String>>.from(custom)
                                        ..removeAt(entry.key);
                                  await widget.storageService
                                      .saveCustomAffirmations(updated);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              )),
                        ],
                        if (custom.isEmpty) ...[
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              'Tap + Add to create your own affirmations',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _affirmationTile({
    required String text,
    required String cat,
    required bool canEdit,
    required VoidCallback? onEdit,
    required VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: canEdit ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: canEdit ? 0.1 : 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: canEdit ? Colors.white : Colors.grey[500],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF6366F1)),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Icons.edit_outlined,
                    color: Colors.grey[600], size: 16),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(Icons.close, color: Colors.grey[600], size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAffirmationDialog(
      BuildContext context, StateSetter setModalState) {
    final textController = TextEditingController();
    final typeController =
        TextEditingController(text: _affirmationCategories[0]);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text(
            'New Affirmation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affirmation text
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'I am…',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Type / category label
              Text(
                'TYPE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              // Free-text type field
              TextField(
                controller: typeController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'e.g. Gratitude, Confidence…',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Quick-select preset chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _affirmationCategories.map((cat) {
                  return GestureDetector(
                    onTap: () {
                      typeController.text = cat;
                      typeController.selection = TextSelection.fromPosition(
                        TextPosition(offset: cat.length),
                      );
                      setDialogState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final cat = typeController.text.trim().isEmpty
                    ? 'Custom'
                    : typeController.text.trim();
                final current =
                    widget.storageService.getCustomAffirmations();
                current.add({'text': text, 'cat': cat});
                await widget.storageService.saveCustomAffirmations(current);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setModalState(() {});
                setState(() {});
              },
              child: const Text('Add',
                  style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAffirmationDialog(
    BuildContext context,
    StateSetter setModalState, {
    required int index,
    required String initialText,
    required String initialCat,
  }) {
    final textController = TextEditingController(text: initialText);
    final typeController = TextEditingController(text: initialCat);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text(
            'Edit Affirmation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'I am…',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TYPE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: typeController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'e.g. Gratitude, Confidence…',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _affirmationCategories.map((cat) {
                  return GestureDetector(
                    onTap: () {
                      typeController.text = cat;
                      typeController.selection = TextSelection.fromPosition(
                        TextPosition(offset: cat.length),
                      );
                      setDialogState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                final cat = typeController.text.trim().isEmpty
                    ? 'Custom'
                    : typeController.text.trim();
                final current =
                    widget.storageService.getCustomAffirmations();
                current[index] = {'text': text, 'cat': cat};
                await widget.storageService.saveCustomAffirmations(current);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setModalState(() {});
                setState(() {});
              },
              child: const Text('Save',
                  style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpotifyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.spotifyService.isConnected
                  ? 'Spotify Connected'
                  : 'Connect to Spotify',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.spotifyService.isConnected)
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF1DB954),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    Navigator.pop(context);
                    await widget.spotifyService.authenticate();
                  },
                  child: const Text(
                    'Connect Spotify',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.spotifyService.openSpotifyPlaylist();
                      },
                      child: const Text(
                        'Open Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () async {
                        await widget.spotifyService.disconnect();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Disconnect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- ALTERNATIVE LINEAR STYLE PICKER METHOD ---
  void _showLinearTimePicker(BuildContext context, StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.white12), // Linear Border
      ),
      builder: (context) => Container(
        height: 320,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          children: [
            // Custom Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                        color: Colors.white, fontSize: 22, fontFamily: 'Inter'),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  backgroundColor: Colors.transparent,
                  // Combine Today's date with existing time to make a valid DateTime object
                  initialDateTime: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _reminderTime.hour,
                    _reminderTime.minute,
                  ),
                  onDateTimeChanged: (DateTime newTime) {
                    final newTimeOfDay = TimeOfDay.fromDateTime(newTime);
                    // Update both the modal state (so text updates) and parent state
                    setModalState(() => _reminderTime = newTimeOfDay);
                    setState(() => _reminderTime = newTimeOfDay);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFFA855F7),
                borderRadius: BorderRadius.circular(12),
                child: const Text(
                  "Set Time",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showReminderSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with icon and title
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFA855F7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFA855F7)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Color(0xFFA855F7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Reminder',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Never miss your nightly ritual',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _reminderEnabled
                                ? const Color(0xFF22C55E)
                                    .withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _reminderEnabled
                                  ? const Color(0xFF22C55E)
                                      .withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            _reminderEnabled ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: _reminderEnabled
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Time selection card
                    GestureDetector(
                      onTap: () {
                        // --- UPDATED: TRIGGER NEW PICKER ---
                        _showLinearTimePicker(context, setModalState);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Reminder Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(_reminderTime),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action button
                    GestureDetector(
                      onTap: () async {
                        if (_reminderEnabled) {
                          await widget.notificationService.cancelReminder();
                          await widget.reminderPrefs.setEnabled(false);
                          setModalState(() {});
                          setState(() => _reminderEnabled = false);
                        } else {
                          final success = await widget.notificationService
                              .scheduleReminderAt(
                                  _reminderTime.hour, _reminderTime.minute);
                          if (success) {
                            await widget.reminderPrefs.setEnabled(true);
                            await widget.reminderPrefs.setTime(
                                _reminderTime.hour, _reminderTime.minute);
                            setModalState(() {});
                            setState(() => _reminderEnabled = true);
                            if (context.mounted) {
                              Navigator.pop(context);
                              widget.notificationService.showTestNotification();
                            }
                          } else {
                            // Show error for unsupported platforms
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  content: const Text(
                                    'Notifications not available on this platform',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: _reminderEnabled
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFA855F7),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                          color: _reminderEnabled
                              ? Colors.white.withValues(alpha: 0.05)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          border: _reminderEnabled
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                )
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _reminderEnabled
                                    ? Icons.notifications_off_outlined
                                    : Icons.notifications_active_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _reminderEnabled
                                    ? 'Disable Reminder'
                                    : 'Enable Reminder',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _BentoCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BentoCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  const _GlassIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: const Color(0xFFD8B4FE), size: 20),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS: Ritual Flow
// -----------------------------------------------------------------------------

class RitualFlow extends StatefulWidget {
  final Future<void> Function() onComplete;
  final VoidCallback onExit;
  final SpotifyService spotifyService;
  final RitualStorageService storageService;

  const RitualFlow({
    super.key,
    required this.onComplete,
    required this.onExit,
    required this.spotifyService,
    required this.storageService,
  });

  @override
  State<RitualFlow> createState() => _RitualFlowState();
}

class _RitualFlowState extends State<RitualFlow> {
  int currentStepIdx = 0;
  final List<Map<String, dynamic>> steps = [
    {'title': 'Breath', 'type': 'breathing', 'desc': 'Resonance breathing.'},
    {'title': 'Audio', 'type': 'music', 'desc': 'Frequency alignment.'},
    {'title': 'Cast', 'type': 'affirmation', 'desc': 'Manifestation.'},
    {'title': 'Seal', 'type': 'reflection', 'desc': 'Lock the energy.'},
  ];

  void nextStep() {
    if (currentStepIdx < steps.length - 1) {
      setState(() => currentStepIdx++);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = steps[currentStepIdx];
    final progress = (currentStepIdx + 1) / steps.length;

    return Column(
      children: [
        const SizedBox(height: 20),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: widget.onExit,
                icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Column(
                children: [
                  Text(
                    'STEP ${currentStepIdx + 1}/${steps.length}',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentStep['title'],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(width: 40), // Balance
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Progress Bar
        SizedBox(
          height: 2,
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.1)),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFF6366F1)]),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content Area
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: KeyedSubtree(
              key: ValueKey(currentStepIdx),
              child: _buildStepContent(currentStep['type']),
            ),
          ),
        ),

        // Footer Nav
        if (currentStep['type'] != 'affirmation')
          Padding(
            padding: const EdgeInsets.all(24),
            child: CupertinoButton(
              onPressed: nextStep,
              padding: EdgeInsets.zero,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentStepIdx == steps.length - 1
                          ? 'Complete Ritual'
                          : 'Continue',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        color: Colors.black, size: 18),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepContent(String type) {
    switch (type) {
      case 'breathing':
        return BreathingStep(onComplete: nextStep);
      case 'music':
        return MusicStep(spotifyService: widget.spotifyService);
      case 'affirmation':
        return AffirmationStep(
            onComplete: nextStep,
            storageService: widget.storageService);
      case 'reflection':
        return const ReflectionStep();
      default:
        return Container();
    }
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS: Steps
// -----------------------------------------------------------------------------

class BreathingStep extends StatefulWidget {
  final VoidCallback onComplete;
  const BreathingStep({super.key, required this.onComplete});

  @override
  State<BreathingStep> createState() => _BreathingStepState();
}

class _BreathingStepState extends State<BreathingStep>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  String phase = 'Inhale';
  int count = 4;
  int cycle = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000));
    _startCycle();
  }

  void _startCycle() {
    if (!mounted) return;
    _controller.repeat(reverse: true); // Pulse effect base
    _runPhase();
  }

  void _runPhase() {
    if (cycle > 4) {
      widget.onComplete();
      return;
    }

    // Inhale: 4s
    setState(() {
      phase = 'Inhale';
      count = 4;
    });
    _tick(4, () {
      // Hold: 7s
      setState(() {
        phase = 'Hold';
        count = 7;
      });
      _tick(7, () {
        // Exhale: 8s
        setState(() {
          phase = 'Exhale';
          count = 8;
        });
        _tick(8, () {
          cycle++;
          _runPhase();
        });
      });
    });
  }

  void _tick(int seconds, VoidCallback onDone) {
    int remaining = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remaining <= 1) {
        timer.cancel();
        onDone();
      } else {
        setState(() => count = --remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    Color ringColor = const Color(0xFFA855F7); // Purple

    if (phase == 'Inhale') {
      scale = 1.5;
    } else if (phase == 'Hold') {
      scale = 1.5;
      ringColor = Colors.white;
    } else {
      scale = 1.0;
      ringColor = const Color(0xFF6366F1); // Indigo
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Orbit
                AnimatedContainer(
                  duration: const Duration(milliseconds: 4000),
                  curve: Curves.easeInOut,
                  width:
                      280 * (phase == 'Inhale' || phase == 'Hold' ? 1.0 : 0.6),
                  height:
                      280 * (phase == 'Inhale' || phase == 'Hold' ? 1.0 : 0.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                // Inner Orbit
                AnimatedContainer(
                  duration: const Duration(milliseconds: 4000),
                  curve: Curves.easeInOut,
                  width:
                      200 * (phase == 'Inhale' || phase == 'Hold' ? 1.0 : 0.7),
                  height:
                      200 * (phase == 'Inhale' || phase == 'Hold' ? 1.0 : 0.7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                // Core
                AnimatedContainer(
                  duration: const Duration(milliseconds: 4000),
                  curve: Curves.easeInOut,
                  width: 120 * scale,
                  height: 120 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                    border: Border.all(
                        color: ringColor.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: ringColor.withValues(alpha: 0.2),
                          blurRadius: 40),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(phase,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            'Cycle $cycle / 4',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class MusicStep extends StatefulWidget {
  final SpotifyService spotifyService;

  const MusicStep({super.key, required this.spotifyService});

  @override
  State<MusicStep> createState() => _MusicStepState();
}

class _MusicStepState extends State<MusicStep> with TickerProviderStateMixin {
  bool isPlaying = false;
  bool isConnecting = false;
  late AnimationController _visualizerController;

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Auto-play if connected
    if (widget.spotifyService.isConnected) {
      _startPlayback();
    }
  }

  @override
  void dispose() {
    _visualizerController.dispose();
    // Pause when leaving this step
    if (isPlaying) {
      widget.spotifyService.pausePlayback();
    }
    super.dispose();
  }

  Future<void> _startPlayback() async {
    setState(() => isConnecting = true);
    final success = await widget.spotifyService.playPlaylist();
    if (mounted) {
      setState(() {
        isPlaying = success;
        isConnecting = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (!widget.spotifyService.isConnected) {
      // Not connected, try to authenticate
      setState(() => isConnecting = true);
      final authenticated = await widget.spotifyService.authenticate();
      if (authenticated && mounted) {
        await _startPlayback();
      } else if (mounted) {
        setState(() => isConnecting = false);
        // Open playlist in browser as fallback
        widget.spotifyService.openSpotifyPlaylist();
      }
      return;
    }

    if (isPlaying) {
      await widget.spotifyService.pausePlayback();
      if (mounted) setState(() => isPlaying = false);
    } else {
      await widget.spotifyService.resumePlayback();
      if (mounted) setState(() => isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.music_note,
                      color: Color(0xFF1DB954), size: 24),
                ),
                // Animated audio visualizer bars
                AnimatedBuilder(
                  animation: _visualizerController,
                  builder: (context, child) {
                    return Row(
                      children: List.generate(5, (index) {
                        final baseHeight = 8.0 + (index % 3) * 6.0;
                        final animatedHeight = isPlaying
                            ? baseHeight +
                                (math.sin(
                                        _visualizerController.value * math.pi +
                                            index * 0.5) *
                                    8)
                            : baseHeight;
                        return Container(
                          margin: const EdgeInsets.only(left: 3),
                          width: 3,
                          height: animatedHeight.abs(),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? const Color(0xFF1DB954)
                                : const Color(0xFFA855F7)
                                    .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Text('Ritual Playlist',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
                const SizedBox(width: 8),
                if (widget.spotifyService.isConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SPOTIFY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1DB954),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isPlaying
                  ? 'Now playing...'
                  : widget.spotifyService.isConnected
                      ? 'Tap to play'
                      : 'Connect to Spotify',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            // Spotify branding
            GestureDetector(
              onTap: () => widget.spotifyService.openSpotifyPlaylist(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Open in Spotify',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: isConnecting ? null : _togglePlayback,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.spotifyService.isConnected
                          ? const Color(0xFF1DB954)
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.spotifyService.isConnected
                                  ? const Color(0xFF1DB954)
                                  : Colors.white)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: isConnecting
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: widget.spotifyService.isConnected
                                ? Colors.white
                                : Colors.black,
                            size: 32,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AffirmationStep extends StatefulWidget {
  final VoidCallback onComplete;
  final RitualStorageService storageService;
  const AffirmationStep(
      {super.key, required this.onComplete, required this.storageService});

  @override
  State<AffirmationStep> createState() => _AffirmationStepState();
}

class _AffirmationStepState extends State<AffirmationStep> {
  static const List<Map<String, dynamic>> _defaultAffirmations = [
    {
      "text": "He feels the weight of his actions and is drawn to me.",
      "cat": "Obsession",
      "icon": Icons.lock
    },
    {
      "text": "His awareness and desire for me grow stronger every day.",
      "cat": "Obsession",
      "icon": Icons.lock
    },
    {
      "text": "I release all attachment and reclaim my inner freedom.",
      "cat": "Detachment",
      "icon": Icons.air
    },
    {
      "text": "I am calm, centered, and emotionally empowered.",
      "cat": "Detachment",
      "icon": Icons.air
    },
    {
      "text": "I radiate natural magnetism while honoring my boundaries.",
      "cat": "Glow Up",
      "icon": Icons.auto_awesome
    },
    {
      "text": "My glow attracts abundance, opportunity, and success.",
      "cat": "Glow Up",
      "icon": Icons.auto_awesome
    },
    {
      "text":
          "My beauty, confidence, and energy open doors for me effortlessly.",
      "cat": "Road Opener",
      "icon": Icons.lock_open
    },
  ];

  static IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Obsession':
        return Icons.lock;
      case 'Detachment':
        return Icons.air;
      case 'Glow Up':
        return Icons.auto_awesome;
      case 'Road Opener':
        return Icons.lock_open;
      default:
        return Icons.star_outline;
    }
  }

  late List<Map<String, dynamic>> _cards;

  @override
  void initState() {
    super.initState();
    final custom = widget.storageService.getCustomAffirmations();
    final customCards = custom
        .map<Map<String, dynamic>>((a) => {
              'text': a['text']!,
              'cat': a['cat']!,
              'icon': _iconForCategory(a['cat']!),
            })
        .toList();
    _cards = [..._defaultAffirmations, ...customCards];
  }

  void _removeCard() {
    setState(() {
      _cards.removeAt(0);
    });
    if (_cards.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty)
      return const Center(
          child: Text("Complete", style: TextStyle(color: Colors.grey)));

    final activeCard = _cards[0];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 20, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activeCard['icon'],
                  size: 14, color: const Color(0xFFA855F7)),
              const SizedBox(width: 6),
              Text(
                activeCard['cat'],
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 400,
          width: 320,
          child: Stack(
            children: _cards.reversed.map((card) {
              final isTop = card == _cards[0];
              return isTop
                  ? Dismissible(
                      key: ValueKey(card),
                      onDismissed: (_) => _removeCard(),
                      child: _buildCardUI(card, isTop: true),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 8), // Stack effect
                      child: Transform.scale(
                          scale: 0.95, child: _buildCardUI(card, isTop: false)),
                    );
            }).toList(),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildCardUI(Map<String, dynamic> card, {required bool isTop}) {
    return Container(
      width: 320,
      height: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: isTop
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CARD",
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600)),
              Text("0${_cards.indexOf(card) + 1}",
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontFamily: 'Monospace')),
            ],
          ),
          Text(
            card['text'],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                height: 1.4,
                color: Colors.white,
                fontWeight: FontWeight.w400),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_left, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text("SWIPE TO ABSORB",
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.swipe_right, size: 16, color: Colors.grey[700]),
            ],
          ),
        ],
      ),
    );
  }
}

class ReflectionStep extends StatelessWidget {
  const ReflectionStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      blurRadius: 30),
                ],
              ),
              child: const Icon(CupertinoIcons.heart_fill,
                  color: Color(0xFFF43F5E), size: 32),
            ),
            const SizedBox(height: 32),
            const Text(
              'The spell is sealed.',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'The energy is locked. Rest well.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                  SizedBox(width: 8),
                  Text(
                    'SEALED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                        letterSpacing: 1),
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
