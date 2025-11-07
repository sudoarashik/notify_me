import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
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

    // প্রতি 10 সেকেন্ডে ad দেখানোর টাইমার
    _interstitialTimer = Timer.periodic(const Duration(seconds: 180), (timer) {
      _showInterstitialAd();
    });
  }

  // 🔹 Banner Load
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ✅ test Banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    );
    _bannerAd.load();
  }

  // 🔹 Interstitial Load
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // ✅ test interstitial ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          debugPrint('InterstitialAd failed: $error');
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
          _loadInterstitialAd(); // ad close হলে আবার load
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      _loadInterstitialAd(); // ready না থাকলে আবার load
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

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) async {},
    );

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
    setState(() {
      _isNotificationsLoaded = true;
    });
  }

  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'instant_channel',
      'Instant Notifications',
      channelDescription: 'This channel is for instant notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification 🚀',
      'This is a test notification ✅',
      platformDetails,
    );

    Future.delayed(const Duration(seconds: 10), () async {
      await flutterLocalNotificationsPlugin.cancel(0);
    });
  }

  Future<void> _scheduleNotification(DateTime dateTime) async {
    final tzTime = tz.TZDateTime.from(dateTime, tz.getLocation('Asia/Dhaka'));

    if (tzTime.isBefore(tz.TZDateTime.now(tz.getLocation('Asia/Dhaka')))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot schedule a notification in the past!'),
        ),
      );
      return;
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'schedule_channel',
      'Scheduled Notifications',
      channelDescription: 'This channel is for scheduled notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'ticker',
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Scheduled Notification 🕒',
      'This is a scheduled notification ⏰',
      tzTime,
      platformDetails,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    final delay =
        tzTime.difference(DateTime.now()) + const Duration(seconds: 10);
    Future.delayed(delay, () async {
      await flutterLocalNotificationsPlugin.cancel(id);
    });

    if (!mounted) return;
    setState(() {
      scheduledNotifications
          .add(ScheduledNotification(dateTime: dateTime, id: id));
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

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notification scheduled at ${DateFormat('hh:mm a, dd MMM yyyy').format(scheduledDateTime)}',
        ),
      ),
    );
  }

  Future<void> _removeNotification(int index) async {
    final notification = scheduledNotifications[index];
    await flutterLocalNotificationsPlugin.cancel(notification.id);

    if (!mounted) return;
    setState(() {
      scheduledNotifications.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification removed ❌')),
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // 🔹 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notify Me',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isBannerAdReady)
            Container(
              width: _bannerAd.size.width.toDouble(),
              height: _bannerAd.size.height.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _bannerAd),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade200],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              child: InkWell(
                                onTap: _showTestNotification,
                                child: Container(
                                  height: 100,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.notifications_active, size: 32),
                                      SizedBox(height: 8),
                                      Text(
                                        'Test Notification',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              child: InkWell(
                                onTap: _pickDateTimeAndSchedule,
                                child: Container(
                                  height: 100,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.schedule, size: 32),
                                      SizedBox(height: 8),
                                      Text(
                                        'Schedule Notification',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!_isNotificationsLoaded)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(color: Colors.black87),
                      ),
                    if (_isNotificationsLoaded &&
                        scheduledNotifications.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          itemCount: scheduledNotifications.length,
                          itemBuilder: (context, index) {
                            final item = scheduledNotifications[index];
                            return Dismissible(
                              key: Key(item.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => _removeNotification(index),
                              child: Card(
                                color: Colors.white.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                                margin:
                                const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.notifications,
                                      color: Colors.black87),
                                  title: const Text(
                                    'This is a scheduled notification ⏰',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  subtitle: Text(
                                    'Date & Time: ${DateFormat('hh:mm a, dd MMM yyyy').format(item.dateTime)}',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
