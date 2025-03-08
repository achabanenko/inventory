import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_settings_service.dart';
import 'database_service.dart';

/// Service for making API requests to the remote server
/// This service handles authentication and error handling for API requests
/// and syncs data with the local database
class ApiService {
  final ApiSettingsService _settingsService = ApiSettingsService();
  final DatabaseService _databaseService = DatabaseService();

  /// Gets a single purchase order from the API and saves it to the local database
  Future<Map<String, dynamic>?> getPurchaseOrder(String orderId) async {
    try {
      // Initialize the database
      await _databaseService.initialize();

      // Try to get data from the API
      final response = await get('api/purchase-orders/$orderId');
      if (response is Map<String, dynamic>) {
        // Save the order to local database
        await _databaseService.savePurchaseOrder(response);
        return response;
      } else {
        debugPrint('Unexpected response format for purchase order: $response');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting purchase order: $e');
      rethrow;
    }
  }

  /// Gets purchase orders from the API and saves them to the local database
  Future<List<dynamic>> getPurchaseOrders(int status) async {
    try {
      // Initialize the database
      await _databaseService.initialize();

      // Try to get data from the API
      final response = await get('api/purchase-orders?status=$status');
      List<dynamic> orders = [];

      // Parse the response based on its structure
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        if (response['data'] is List) {
          orders = response['data'] as List<dynamic>;
        }
      } else if (response is Map<String, dynamic>) {
        // Try to extract values if the response is a map of purchase orders
        orders = response.values.toList();
      } else if (response is List) {
        // If it's already a list, use it directly
        orders = response;
      } else {
        debugPrint('Unexpected response format for purchase orders: $response');
        // Try to get orders from local database if API fails
        return await _getOrdersFromLocalDatabase();
      }

      // Save orders to local database
      if (orders.isNotEmpty && orders[0] is List) {
        // Handle nested list structure if present
        final List<Map<String, dynamic>> purchaseOrders =
            List<Map<String, dynamic>>.from(orders[0]);
        await _savePurchaseOrdersToLocalDatabase(purchaseOrders);
      } else if (orders.isNotEmpty) {
        // Handle flat list structure
        final List<Map<String, dynamic>> purchaseOrders =
            List<Map<String, dynamic>>.from(orders);
        await _savePurchaseOrdersToLocalDatabase(purchaseOrders);
      }

      return orders;
    } catch (e) {
      debugPrint('Error fetching purchase orders from API: $e');
      // Fallback to local database if API fails
      return await _getOrdersFromLocalDatabase();
    }
  }

  /// Get purchase orders from local database
  Future<List<dynamic>> _getOrdersFromLocalDatabase() async {
    try {
      final orders = await _databaseService.getAllPurchaseOrders();
      if (orders.isEmpty) {
        return [];
      }
      return [orders]; // Match the API response format
    } catch (e) {
      debugPrint('Error getting purchase orders from local database: $e');
      return [];
    }
  }

  /// Save purchase orders to local database
  Future<void> _savePurchaseOrdersToLocalDatabase(
    List<Map<String, dynamic>> orders,
  ) async {
    try {
      await _databaseService.savePurchaseOrders(orders);
      debugPrint('${orders.length} purchase orders saved to local database');
    } catch (e) {
      debugPrint('Error saving purchase orders to local database: $e');
    }
  }

  /// Update a purchase order in the local database
  Future<void> updatePurchaseOrderInLocalDatabase(
    Map<String, dynamic> order,
  ) async {
    try {
      final orderId = order['id']?.toString() ?? '';
      if (orderId.isEmpty) {
        throw Exception('Purchase order ID is required');
      }

      await _databaseService.updatePurchaseOrder(orderId, order);
      debugPrint('Purchase order updated in local database: $orderId');
    } catch (e) {
      debugPrint('Error updating purchase order in local database: $e');
      rethrow;
    }
  }

  /// Makes a GET request to the specified endpoint
  Future<dynamic> get(String endpoint) async {
    final apiUrl = await _settingsService.getApiUrl();
    final apiKey = await _settingsService.getApiKey();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception(
        'API URL or API Key not configured. Please set up API settings first.',
      );
    }

    final url = Uri.parse('$apiUrl/$endpoint');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'X-API-KEY': apiKey},
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Makes a POST request to the specified endpoint with the given data
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final apiUrl = await _settingsService.getApiUrl();
    final apiKey = await _settingsService.getApiKey();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception(
        'API URL or API Key not configured. Please set up API settings first.',
      );
    }

    final url = Uri.parse('$apiUrl/$endpoint');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-API-KEY': apiKey},
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Makes a PUT request to the specified endpoint with the given data
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final apiUrl = await _settingsService.getApiUrl();
    final apiKey = await _settingsService.getApiKey();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception(
        'API URL or API Key not configured. Please set up API settings first.',
      );
    }

    final url = Uri.parse('$apiUrl/$endpoint');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'X-API-KEY': apiKey},
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Makes a DELETE request to the specified endpoint
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final apiUrl = await _settingsService.getApiUrl();
    final apiKey = await _settingsService.getApiKey();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception(
        'API URL or API Key not configured. Please set up API settings first.',
      );
    }

    final url = Uri.parse('$apiUrl/$endpoint');

    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json', 'X-API-KEY': apiKey},
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Handle API response and parse JSON
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success response
      if (response.body.isEmpty) {
        return {};
      }

      return json.decode(response.body);
    } else {
      // Error response
      String message;

      try {
        final errorData = json.decode(response.body);
        message = errorData['message'] ?? 'Unknown error occurred';
      } catch (_) {
        message = 'Error: ${response.statusCode}';
      }

      throw Exception(message);
    }
  }
}
