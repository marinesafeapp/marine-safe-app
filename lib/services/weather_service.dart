import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Mackay QLD coordinates (you can update later to GPS)
  static const double lat = -21.1411;
  static const double lon = 149.1860;

  // API key (works for your testing)
  static const String apiKey = "b5f3fb1574994b69be53fb9f52c6cdae";

  static Future<Map<String, dynamic>> getWeather() async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey",
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Weather API error ${response.statusCode}");
    }

    final json = jsonDecode(response.body);

    final temp = json["main"]["temp"];
    final humidity = json["main"]["humidity"];
    final windSpeed = json["wind"]["speed"];
    final windDeg = json["wind"]["deg"];
    final condition = json["weather"][0]["main"];

    return {
      "temp": temp.toString(),
      "humidity": humidity.toString(),
      "wind": "$windSpeed m/s (${_directionFromDegrees(windDeg)})",
      "condition": condition,
    };
  }

  static String _directionFromDegrees(num deg) {
    if (deg >= 337.5 || deg < 22.5) return "N";
    if (deg < 67.5) return "NE";
    if (deg < 112.5) return "E";
    if (deg < 157.5) return "SE";
    if (deg < 202.5) return "S";
    if (deg < 247.5) return "SW";
    if (deg < 292.5) return "W";
    return "NW";
  }
}
