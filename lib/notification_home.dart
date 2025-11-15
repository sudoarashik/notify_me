import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class ScheduledNotification {
  final DateTime dateTime;
  final int id;

  ScheduledNotification({required this.dateTime, required this.id});
}

class NotificationHome extends StatefulWidget {
  const NotificationHome({super.key});

  @override
  State<NotificationHome> createState() => _NotificationHomeState();
}

class _NotificationHomeState extends State<NotificationHome> {
  final List<ScheduledNotification> scheduledNotifications = [];
  bool _isNotificationsLoaded = false;

  // ✅ Banner Ad variables
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  // ✅ Interstitial Ad variables
  InterstitialAd? _interstitialAd;
  Timer? _interstitialTimer;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadBannerAd();
    _loadInterstitialAd();

    // Interstitial ad every 3 minutes
    _interstitialTimer = Timer.periodic(const Duration(seconds: 180), (timer) {
      _showInterstitialAd();
    });
  }

  // 🔹 Banner Load
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // test id
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('❌ BannerAd failed: $error');
        },
      ),
    );
    _bannerAd.load();
  }

  // 🔹 Interstitial Load
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // test id
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          debugPrint('❌ InterstitialAd failed: $error');
        },
      ),
    );
  }

  // 🔹 Interstitial Show
  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    _interstitialTimer?.cancel();
    super.dispose();
  }

  // 🔹 Notification Setup
  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'schedule_channel',
      'Scheduled Notifications',
      description: 'This channel is for scheduled notifications',
      importance: Importance.max,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    if (!mounted) return;
    setState(() => _isNotificationsLoaded = true);
  }

  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'instant_channel',
      'Instant Notifications',
      channelDescription: 'This channel is for instant notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification 🚀',
      'This is a test notification ✅',
      platformDetails,
    );
  }

  Future<void> _scheduleNotification(DateTime dateTime) async {
    final tzTime = tz.TZDateTime.from(dateTime, tz.getLocation('Asia/Dhaka'));
    if (tzTime.isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Dhaka')))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot schedule a notification in the past!'),
      ));
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'schedule_channel',
      'Scheduled Notifications',
      channelDescription: 'This channel is for scheduled notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Scheduled Notification 🕒',
      'This is a scheduled notification ⏰',
      tzTime,
      platformDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    if (!mounted) return;
    setState(() {
      scheduledNotifications.add(ScheduledNotification(dateTime: dateTime, id: id));
    });
  }

  Future<void> _pickDateTimeAndSchedule() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime == null) return;

    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await _scheduleNotification(scheduledDateTime);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Notification scheduled at ${DateFormat('hh:mm a, dd MMM yyyy').format(scheduledDateTime)}',
      ),
    ));
  }

  Future<void> _removeNotification(int index) async {
    final notification = scheduledNotifications[index];
    await flutterLocalNotificationsPlugin.cancel(notification.id);
    if (!mounted) return;
    setState(() => scheduledNotifications.removeAt(index));
  }

  // 🔹 Logout function (SharedPreferences)
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // 🔹 UI (Dark Galaxy Theme)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D071F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1035),
        elevation: 6,
        centerTitle: true,
        title: const Text(
          'Notify Me',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1B1035),
              Color(0xFF2E1747),
              Color(0xFF000000),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (_isBannerAdReady)
              Container(
                alignment: Alignment.center,
                width: _bannerAd.size.width.toDouble(),
                height: _bannerAd.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      icon: Icons.notifications_active_rounded,
                      text: 'Test Notification',
                      onTap: _showTestNotification,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _actionCard(
                      icon: Icons.schedule_rounded,
                      text: 'Schedule Notification',
                      onTap: _pickDateTimeAndSchedule,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isNotificationsLoaded
                  ? (scheduledNotifications.isEmpty
                  ? const Center(
                child: Text(
                  'No notifications scheduled yet 🌙',
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: scheduledNotifications.length,
                itemBuilder: (context, index) {
                  final item = scheduledNotifications[index];
                  return Dismissible(
                    key: Key(item.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _removeNotification(index),
                    child: Card(
                      color: Colors.white.withOpacity(0.08),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.notifications, color: Colors.white70),
                        title: const Text(
                          'Scheduled Notification ⏰',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('hh:mm a, dd MMM yyyy').format(item.dateTime),
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ))
                  : const Center(
                  child: CircularProgressIndicator(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
