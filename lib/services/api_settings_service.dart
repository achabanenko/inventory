import 'package:shared_preferences/shared_preferences.dart';

class ApiSettings {
  final String apiUrl;
  final String apiKey;

  ApiSettings({
    required this.apiUrl,
    required this.apiKey,
  });

  factory ApiSettings.empty() {
    return ApiSettings(
      apiUrl: '',
      apiKey: '',
    );
  }
}

class ApiSettingsService {
  static const String _apiUrlKey = 'api_url';
  static const String _apiKeyKey = 'api_key';

  /// Retrieves the saved API settings from local storage
  Future<ApiSettings> getApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return ApiSettings(
      apiUrl: prefs.getString(_apiUrlKey) ?? '',
      apiKey: prefs.getString(_apiKeyKey) ?? '',
    );
  }

  /// Saves the API settings to local storage
  Future<void> saveApiSettings(ApiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_apiUrlKey, settings.apiUrl);
    await prefs.setString(_apiKeyKey, settings.apiKey);
  }

  /// Helper method to retrieve the API URL only
  Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? '';
  }

  /// Helper method to retrieve the API key only
  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  /// Clears all API settings from local storage
  Future<void> clearApiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_apiUrlKey);
    await prefs.remove(_apiKeyKey);
  }
}