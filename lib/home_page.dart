import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/weather_model.dart';
import 'services/open_meteo_service.dart';
import 'login_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class NotificationWeatherHome extends StatefulWidget {
  const NotificationWeatherHome({super.key});

  @override
  State<NotificationWeatherHome> createState() =>
      _NotificationWeatherHomeState();
}

class _NotificationWeatherHomeState extends State<NotificationWeatherHome>
    with TickerProviderStateMixin {
  // Switch Pages
  int selectedPage = 0;

  // Weather Variables
  final weatherService = OpenMeteoService();
  WeatherModel? weather;
  bool isLoadingWeather = true;
  Timer? weatherTimer;
  String lastUpdated = "—";
  late AnimationController cloudController;

  // Notification Variables
  final List<ScheduledNotification> scheduledNotifications = [];
  bool _isNotificationsLoaded = false;

  // Banner Ad
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  Timer? _interstitialTimer;

  // Localization (simple internal map)
  String _localeCode = 'en'; // 'en' or 'bn'
  static const _localePrefKey = 'selected_locale';

  // Simple translations map for this page
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'title': 'Notify & Weather',
      'notifications_tab': 'Notifications',
      'weather_tab': 'Weather',
      'logout': 'Logout',
      'test': 'Test',
      'schedule': 'Schedule',
      'cant_schedule_past': "Can't schedule notification in the past",
      'scheduled_notification_title': 'Scheduled Notification',
      'scheduled_alert': 'Scheduled Alert',
      'no_scheduled': 'No Scheduled Alerts',
      'test_notification_title': 'Test Notification',
      'test_notification_body': 'This is a test!',
      'scheduled_at': 'Scheduled at',
      'last_updated': 'Last Updated',
      'instant_channel_name': 'Instant Notifications',
      'scheduled_channel_name': 'Scheduled Notifications',
      'reminder_alert': 'Reminder Alert!',
    },
    'bn': {
      'title': 'নোটিফাই ও আবহাওয়া',
      'notifications_tab': 'নোটিফিকেশন',
      'weather_tab': 'আবহাওয়া',
      'logout': 'লগআউট',
      'test': 'টেস্ট',
      'schedule': 'নির্ধারণ',
      'cant_schedule_past': "অতীতে আলার্ম নির্ধারণ করা যাবে না",
      'scheduled_notification_title': 'নির্ধারিত নোটিফিকেশন',
      'scheduled_alert': 'নির্ধারিত অ্যালার্ট',
      'no_scheduled': 'কোনো নির্ধারিত অ্যালার্ট নেই',
      'test_notification_title': 'টেস্ট নোটিফিকেশন',
      'test_notification_body': 'এটি একটি টেস্ট!',
      'scheduled_at': 'নির্ধারিত সময়',
      'last_updated': 'শেষ আপডেট',
      'instant_channel_name': 'তাৎক্ষণিক নোটিফিকেশন',
      'scheduled_channel_name': 'নির্ধারিত নোটিফিকেশন',
      'reminder_alert': 'রিমাইন্ডার এলার্ট!',
    }
  };

  String _t(String key) {
    return _translations[_localeCode]?[key] ??
        _translations['en']![key] ??
        key;
  }

  @override
  void initState() {
    super.initState();

    // Load saved locale
    _loadSavedLocale();

    // WEATHER INIT
    loadWeather();
    weatherTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) => loadWeather());
    cloudController =
    AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..repeat();

    // NOTIFICATION INIT
    _initNotifications();

    // ADS INIT
    _loadBannerAd();
    _loadInterstitialAd();
    _interstitialTimer = Timer.periodic(const Duration(seconds: 180), (timer) {
      _showInterstitialAd();
    });
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefKey);
    if (code != null && (code == 'en' || code == 'bn')) {
      setState(() {
        _localeCode = code;
      });
    }
  }

  Future<void> _saveLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, code);
  }

  @override
  void dispose() {
    cloudController.dispose();
    weatherTimer?.cancel();
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    super.dispose();
  }

  // ===================================================================
  // WEATHER SECTION
  // ===================================================================

  Future<void> loadWeather() async {
    try {
      final data = await weatherService.getWeather(23.8103, 90.4125);
      setState(() {
        weather = WeatherModel.fromJson(data);
        isLoadingWeather = false;
        lastUpdated = DateFormat('hh:mm a', _localeCode)
            .format(DateTime.now()); // locale-aware format
      });
    } catch (e) {
      setState(() {
        isLoadingWeather = false;
        lastUpdated = "Error";
      });
    }
  }

  // ===================================================================
  // NOTIFICATION SECTION
  // ===================================================================

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Rajshahi'));

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'schedule_channel',
      'Scheduled Notifications',
      importance: Importance.max,
      description: 'Used for scheduled notifications',
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    setState(() => _isNotificationsLoaded = true);
  }

  Future<void> _scheduleNotification(DateTime dateTime) async {
    final tzTime = tz.TZDateTime.from(dateTime, tz.local);

    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t("cant_schedule_past"))),
      );
      return;
    }

    final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_channel',
          _t('scheduled_channel_name'),
          importance: Importance.max,
          priority: Priority.high,
        ));

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      _t('scheduled_notification_title'),
      _t('reminder_alert'),
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    setState(() {
      scheduledNotifications
          .add(ScheduledNotification(dateTime: dateTime, id: id));
    });
  }

  Future<void> pickScheduleTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (date == null) return;

    final time =
    await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    final finalDT =
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

    await _scheduleNotification(finalDT);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "${_t('scheduled_at')} ${DateFormat('hh:mm a, dd MMM yyyy', _localeCode).format(finalDT)}")),
    );
  }

  // ===================================================================
  // ADS (🔥 FIXED VERSION)
  // ===================================================================

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBannerAdReady = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _isBannerAdReady = false);
          debugPrint("Banner Ad Failed: $error");
        },
      ),
    );

    _bannerAd.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint("Interstitial Failed: $error");
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  // ===================================================================
  // LOGOUT
  // ===================================================================

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  // ===================================================================
  // PAGE UI
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // SOFT LIGHT BLUE
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent, // LIGHT SKY BLUE
        title: Text(_t('title'), style: const TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Language selector as popup menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == _localeCode) return;
                setState(() {
                  _localeCode = value;
                  // update lastUpdated to reflect new locale format
                  lastUpdated = isLoadingWeather
                      ? lastUpdated
                      : DateFormat('hh:mm a', _localeCode)
                      .format(DateTime.now());
                });
                _saveLocale(value);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'en',
                  child: Row(
                    children: const [Text('English')],
                  ),
                ),
                PopupMenuItem(
                  value: 'bn',
                  child: Row(
                    children: const [Text('বাংলা')],
                  ),
                ),
              ],
              icon: const Icon(Icons.language, color: Colors.black87),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: _t('logout'),
          )
        ],
        bottom: TabBar(
          controller:
          TabController(length: 2, vsync: this, initialIndex: selectedPage),
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          onTap: (i) => setState(() => selectedPage = i),
          tabs: [
            Tab(icon: const Icon(Icons.notifications), text: _t('notifications_tab')),
            Tab(icon: const Icon(Icons.cloud), text: _t('weather_tab')),
          ],
        ),
      ),
      body: selectedPage == 0 ? buildNotificationPage() : buildWeatherPage(),
    );
  }

  // ===================================================================
  // NOTIFICATION PAGE
  // ===================================================================

  Widget buildNotificationPage() {
    return Column(
      children: [
        if (_isBannerAdReady)
          SizedBox(
            height: _bannerAd.size.height.toDouble(),
            width: _bannerAd.size.width.toDouble(),
            child: AdWidget(ad: _bannerAd),
          ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _actionCard(Icons.notifications_active, _t('test'), () {
                    flutterLocalNotificationsPlugin.show(
                      111,
                      _t('test_notification_title'),
                      _t('test_notification_body'),
                      NotificationDetails(
                        android: AndroidNotificationDetails(
                          'instant',
                          _t('instant_channel_name'),
                          importance: Importance.max,
                        ),
                      ),
                    );
                  })),
              const SizedBox(width: 16),
              Expanded(
                  child:
                  _actionCard(Icons.schedule, _t('schedule'), pickScheduleTime)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: !_isNotificationsLoaded
              ? const Center(
              child: CircularProgressIndicator(color: Colors.black54))
              : (scheduledNotifications.isEmpty
              ? Center(
              child: Text(_t('no_scheduled'),
                  style: const TextStyle(color: Colors.black54)))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scheduledNotifications.length,
            itemBuilder: (_, index) {
              final item = scheduledNotifications[index];
              return Card(
                color: Colors.white.withOpacity(0.8),
                child: ListTile(
                  title: Text(_t('scheduled_alert'),
                      style: const TextStyle(color: Colors.black87)),
                  subtitle: Text(
                    DateFormat('hh:mm a, dd MMM yyyy', _localeCode)
                        .format(item.dateTime),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        flutterLocalNotificationsPlugin.cancel(item.id);
                        setState(() => scheduledNotifications.removeAt(index));
                      }),
                ),
              );
            },
          )),
        ),
      ],
    );
  }

  Widget _actionCard(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(height: 6),
            Text(text,
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // WEATHER PAGE
  // ===================================================================

  Widget buildWeatherPage() {
    final w = MediaQuery.of(context).size.width;

    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.lightBlue.shade200,
            Colors.lightBlue.shade100,
            Colors.cyan.shade50,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: isLoadingWeather
          ? const Center(
          child: CircularProgressIndicator(color: Colors.black54))
          : Stack(
        children: [
          AnimatedBuilder(
            animation: cloudController,
            builder: (_, __) => Positioned(
              left: (w + 120) * cloudController.value - 120,
              top: 120,
              child: const Opacity(
                opacity: 0.4,
                child: Icon(Icons.cloud_rounded,
                    size: 140, color: Colors.grey),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 2),
                          builder: (_, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: const Icon(Icons.wb_sunny_rounded,
                              size: 60, color: Colors.amber),
                        ),
                        const SizedBox(height: 10),
                        Text("${weather!.temperature}°C",
                            style: const TextStyle(
                                fontSize: 48,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.water_drop,
                                size: 22, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text("${weather!.humidity}%",
                                style: const TextStyle(
                                    fontSize: 22, color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text("${_t('last_updated')}: $lastUpdated",
                  style:
                  const TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

class ScheduledNotification {
  final DateTime dateTime;
  final int id;
  ScheduledNotification({required this.dateTime, required this.id});
}
