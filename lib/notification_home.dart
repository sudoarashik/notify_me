import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {},
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
            content: Text('Cannot schedule a notification in the past!')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showTestNotification,
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Send Test Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickDateTimeAndSchedule,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Schedule Notification (Date & Time)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!_isNotificationsLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LinearProgressIndicator(color: Colors.white),
                ),
              if (_isNotificationsLoaded && scheduledNotifications.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child:
                          const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeNotification(index),
                        child: Card(
                          color: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.notifications,
                                color: Colors.blueAccent),
                            title: const Text(
                              'This is a scheduled notification ⏰',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            subtitle: Text(
                              'Date & Time: ${DateFormat('hh:mm a, dd MMM yyyy').format(item.dateTime)}',
                              style: const TextStyle(color: Colors.white70),
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
    );
  }
}
