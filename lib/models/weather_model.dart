class WeatherModel {
  final double temperature;
  final int humidity;

  WeatherModel({
    required this.temperature,
    required this.humidity,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      temperature: json["current"]["temperature_2m"].toDouble(),
      humidity: json["current"]["relative_humidity_2m"].toInt(),
    );
  }
}
