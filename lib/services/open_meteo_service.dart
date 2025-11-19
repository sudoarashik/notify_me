import 'package:dio/dio.dart';

class OpenMeteoService {
  final Dio dio = Dio();

  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    final url =
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m";

    try {
      final response = await dio.get(url);
      return response.data; // JSON object
    } catch (e) {
      throw Exception("Weather fetch failed: $e");
    }
  }
}
