import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MyApp());

// Data Models 

class WeatherDetail {
  final String title;
  final String value;
  final IconData icon;

  const WeatherDetail({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class DailyForecast {
  final String date;
  final double maxTempC;
  final double minTempC;
  final String condition;
  final IconData icon;

  DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.condition,
    required this.icon,
  });
}

class CurrentWeather {
  final double tempC;
  final String condition;
  final String location;
  final IconData icon;

  const CurrentWeather({
    required this.tempC,
    required this.condition,
    required this.location,
    required this.icon,
  });
}


// API Models 

class WeatherApiResponse {
  final String location;
  final double tempC;
  final String condition;
  final List<DailyForecast> dailyForecast;

  WeatherApiResponse({
    required this.location,
    required this.tempC,
    required this.condition,
    required this.dailyForecast,
  });

  factory WeatherApiResponse.fromJson(Map<String, dynamic> json) {
    return WeatherApiResponse(
      location: json['location'],
      tempC: json['temp_c'],
      condition: json['condition'],
      dailyForecast: List<DailyForecast>.from(
        json['daily_forecast'].map((day) => DailyForecast(
          date: day['date'],
          maxTempC: day['max_temp_c'],
          minTempC: day['min_temp_c'],
          condition: day['condition'],
          icon: _getWeatherIconFromCondition(day['condition']),
        )),
      ),
    );
  }

  static IconData _getWeatherIconFromCondition(String condition) {
    if (condition.toLowerCase().contains('rain')) {
      return WeatherIcons.rain;
    } else if (condition.toLowerCase().contains('cloud')) {
      return WeatherIcons.cloudy;
    } else if (condition.toLowerCase().contains('sun') || 
               condition.toLowerCase().contains('clear')) {
      return WeatherIcons.day_sunny;
    } else {
      return WeatherIcons.day_sunny;
    }
  }
}

// Weather Service 

class WeatherService {
  static const String _baseUrl = 'http://<IP>:8080'; 
  static const Duration _timeoutDuration = Duration(seconds: 10);

  Future<WeatherApiResponse> fetchWeather(String location) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?location=$location'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return WeatherApiResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Server responded with ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } on FormatException {
      throw Exception('Invalid data format from server');
    } on http.ClientException {
      throw Exception('Failed to connect to the server');
    } catch (e) {
      throw Exception('Failed to load weather data: ${e.toString()}');
    }
  }
}


// Main App

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SamsungOne',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _locationController = TextEditingController();
  bool _useFahrenheit = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  Position? _currentPosition;
  WeatherApiResponse? _weatherData;
  bool _isLoading = false;
  String _errorMessage = '';
  String _lastLocation = 'London';
  bool _showingGpsLocation = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadTemperatureUnitPreference();
    await _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('lastLocation');
    
    if (savedLocation != null && savedLocation.isNotEmpty) {
      if (savedLocation.contains(',')) {
        final parts = savedLocation.split(',');
        setState(() {
          _currentPosition = Position(
            latitude: double.parse(parts[0]),
            longitude: double.parse(parts[1]),
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          _showingGpsLocation = true;
        });
      }
      await _fetchWeather(savedLocation);
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are required')),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      await _fetchWeather('${position.latitude},${position.longitude}');
      setState(() {
        _currentPosition = position;
        _showingGpsLocation = true;
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: ${e.toString()}')),
      );
      await _fetchWeather(_lastLocation);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _saveLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLocation', location);
  }

  Future<void> _fetchWeather(String location) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showingGpsLocation = location.contains(',');
    });

    final isConnected = await _checkInternetConnection();
    if (!isConnected) {
      setState(() {
        _errorMessage = 'No internet connection. Showing cached data if available.';
        _isLoading = false;
      });
      return;
    }

    try {
      final weatherData = await _weatherService.fetchWeather(location);
      await _saveLocation(location);
      
      setState(() {
        _weatherData = weatherData;
        _lastLocation = location;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTemperatureUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useFahrenheit = prefs.getBool('useFahrenheit') ?? false;
    });
  }

  Future<void> _saveTemperatureUnitPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useFahrenheit', value);
  }

  Future<void> _handleRefresh() async {
    await _fetchWeather(_lastLocation);
  }

  String _formatTemperature(double tempC) {
    if (_useFahrenheit) {
      final tempF = (tempC * 9 / 5) + 32;
      return '${tempF.round()}°F';
    }
    return '${tempC.round()}°C';
  }

  CurrentWeather _getCurrentWeather() {
    if (_weatherData == null) {
      return const CurrentWeather(
        tempC: 0,
        condition: 'Sunny',
        location: 'London',
        icon: WeatherIcons.day_sunny,
      );
    }
    
    return CurrentWeather(
      tempC: _weatherData!.tempC,
      condition: _weatherData!.condition,
      location: _weatherData!.location,
      icon: WeatherApiResponse._getWeatherIconFromCondition(_weatherData!.condition),
    );
  }

  List<WeatherDetail> _getWeatherDetails() {
    if (_weatherData == null) {
      return const [
        WeatherDetail(title: 'Humidity', value: '65%', icon: WeatherIcons.humidity),
        WeatherDetail(title: 'Wind', value: '12 km/h', icon: WeatherIcons.strong_wind),
      ];
    }
    
    return [
      WeatherDetail(title: 'Location', value: _weatherData!.location, icon: Icons.location_on),
      WeatherDetail(title: 'Condition', value: _weatherData!.condition, 
                   icon: WeatherApiResponse._getWeatherIconFromCondition(_weatherData!.condition)),
    ];
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter city name',
                errorText: _locationController.text.isEmpty ? 'Please enter a location' : null,
              ),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_locationController.text.isEmpty) {
                setState(() => _errorMessage = 'Please enter a location');
                return;
              }
              
              try {
                await _fetchWeather(_locationController.text);
                Navigator.pop(context);
                _locationController.clear();
              } catch (e) {
                Navigator.pop(context);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_weatherData == null) return Colors.blue.shade800;
    
    final hour = DateTime.now().hour;
    final isDayTime = hour >= 6 && hour < 18;
    final condition = _weatherData!.condition.toLowerCase();
    
    if (condition.contains('rain')) {
      return Colors.blueGrey.shade800;
    } else if (condition.contains('cloud')) {
      return isDayTime ? Colors.blue.shade600 : Colors.blue.shade900;
    } else {
      return isDayTime ? Colors.blue.shade400 : Colors.blue.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeather = _getCurrentWeather();
    final weatherDetails = _getWeatherDetails();

    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _getBackgroundColor(),
                _getBackgroundColor().withOpacity(0.8),
                Colors.blue.shade900,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with location and unit toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_location_alt, color: Colors.white),
                        onPressed: _showLocationDialog,
                      ),
                      Text(
                        currentWeather.location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _useFahrenheit ? '°F' : '°C',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Switch(
                            value: _useFahrenheit,
                            onChanged: (value) {
                              setState(() {
                                _useFahrenheit = value;
                              });
                              _saveTemperatureUnitPreference(value);
                            },
                            activeColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (_errorMessage.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () => _fetchWeather(_lastLocation),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // Current weather
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(
                                  currentWeather.icon,
                                  size: 100,
                                  color: Colors.white,
                                ),
                                Text(
                                  _formatTemperature(currentWeather.tempC),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 72,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                Text(
                                  currentWeather.condition,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Daily forecast
                          if (_weatherData != null)
                            Container(
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: _weatherData!.dailyForecast.map((day) => ListTile(
                                  leading: Text(
                                    DateFormat('EEEE').format(DateTime.parse(day.date)),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(day.icon, color: Colors.white, size: 20),
                                      const SizedBox(width: 16),
                                      Text(
                                        _formatTemperature(day.maxTempC),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        _formatTemperature(day.minTempC),
                                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),

                          // Weather details grid
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: weatherDetails.map((detail) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      detail.icon,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      detail.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      detail.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentPosition != null && !_showingGpsLocation
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                await _getCurrentLocation();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Returning to current location')),
                );
              },
              tooltip: 'Return to current location',
              child: const Icon(Icons.gps_fixed, color: Colors.blue),
            )
          : null,
    );
  }
}