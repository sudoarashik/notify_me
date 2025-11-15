import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'models/weather_model.dart';
import 'services/open_meteo_service.dart';
import 'package:intl/intl.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage>
    with SingleTickerProviderStateMixin {
  final weatherService = OpenMeteoService();

  WeatherModel? weather;
  bool isLoading = true;
  Timer? timer;
  String lastUpdated = "—";

  late AnimationController cloudController;

  @override
  void initState() {
    super.initState();
    loadWeather();

    // auto update every 5 minutes
    timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      loadWeather();
    });

    // cloud movement animation
    cloudController =
    AnimationController(vsync: this, duration: const Duration(seconds: 15))
      ..repeat();
  }

  @override
  void dispose() {
    cloudController.dispose();
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadWeather() async {
    try {
      final data = await weatherService.getWeather(23.8103, 90.4125);
      setState(() {
        weather = WeatherModel.fromJson(data);
        isLoading = false;
        lastUpdated = DateFormat('hh:mm a').format(DateTime.now());
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        lastUpdated = "Error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 2),

        // Animated gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade400,
              Colors.cyan.shade300,
              Colors.lightBlue.shade200,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : Stack(
          children: [
            // ---------------- Animated Cloud ICON ----------------
            AnimatedBuilder(
              animation: cloudController,
              builder: (_, child) {
                return Positioned(
                  left: (screenW + 100) * cloudController.value - 100,
                  top: 120,
                  child: Opacity(
                    opacity: 0.35,
                    child: Icon(
                      Icons.cloud_rounded,
                      size: 140,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            // ---------------- Main Weather UI ----------------
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Sun icon animation
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(seconds: 2),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: const Icon(
                                    Icons.wb_sunny_rounded,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            Text(
                              "${weather!.temperature}°C",
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.water_drop,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 6),
                                Text(
                                  "${weather!.humidity}%",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  "Last Updated: $lastUpdated",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
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
