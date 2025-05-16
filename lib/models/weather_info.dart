class WeatherInfo {
  final String date;
  final String condition; // 'sunny', 'cloudy', 'rainy', 'snowy' 등
  final double temperature;
  final double lat;
  final double lon;

  WeatherInfo({
    required this.date,
    required this.condition,
    required this.temperature,
    required this.lat,
    required this.lon,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json, String date, double lat, double lon) {
    // OpenWeatherMap API의 응답을 파싱
    final weather = json['weather'][0]['main'].toString().toLowerCase();
    String condition;
    
    // 날씨 상태 매핑
    if (weather.contains('clear')) {
      condition = 'sunny';
    } else if (weather.contains('cloud') || weather.contains('overcast')) {
      condition = 'cloudy';
    } else if (weather.contains('rain') || weather.contains('drizzle')) {
      condition = 'rainy';
    } else if (weather.contains('snow')) {
      condition = 'snowy';
    } else {
      condition = 'cloudy'; // 기본값
    }

    return WeatherInfo(
      date: date,
      condition: condition,
      temperature: (json['main']['temp'] as num).toDouble(),
      lat: lat,
      lon: lon,
    );
  }
} 