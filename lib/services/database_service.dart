import 'dart:async';
import 'package:cbl/cbl.dart';
import 'package:flutter/foundation.dart';

/// Service for managing local database operations using Couchbase Lite
class DatabaseService {
  static const String _databaseName = 'inventory_db';
  static const String _purchaseOrdersCollectionName = 'purchaseorders';
  // static String _deviceId = '';

  Database? _database;
  Collection? _purchaseOrdersCollection;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// Initialize the database and collections
  Future<void> initialize() async {
    if (_database != null) return; // Already initialized

    try {
      // Skip Couchbase Lite initialization if already done in main.dart
      // await CouchbaseLiteFlutter.init();

      // Open or create the database
      _database = await Database.openAsync(_databaseName);
      debugPrint('Database opened: $_databaseName');

      // Create or get the purchase orders collection
      _purchaseOrdersCollection = await _getOrCreateCollection(
        _purchaseOrdersCollectionName,
      );
      debugPrint('Collection created/opened: $_purchaseOrdersCollectionName');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  /// Get or create a collection
  Future<Collection> _getOrCreateCollection(String collectionName) async {
    if (_database == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Check if collection exists in the default scope
      final collections = await _database!.collections();
      Collection? existingCollection;

      for (final collection in collections) {
        if (collection.name == collectionName) {
          existingCollection = collection;
          break;
        }
      }

      if (existingCollection != null) {
        return existingCollection;
      }

      // Create new collection in the default scope
      return await _database!.createCollection(collectionName);
    } catch (e) {
      debugPrint('Error creating collection: $e');
      rethrow;
    }
  }

  /// Save a purchase order to the local database
  Future<void> savePurchaseOrder(Map<String, dynamic> purchaseOrder) async {
    if (_purchaseOrdersCollection == null) {
      await initialize();
    }

    try {
      final String orderId = purchaseOrder['id'] ?? '';
      if (orderId.isEmpty) {
        throw Exception('Purchase order ID is required');
      }

      // Create a document
      final doc = MutableDocument.withId(orderId);

      // Add all properties from the purchase order
      purchaseOrder.forEach((key, value) {
        doc.setValue(value, key: key);
      });

      // Save the document to the collection
      await _purchaseOrdersCollection!.saveDocument(doc);
      debugPrint('Purchase order saved: $orderId');
    } catch (e) {
      debugPrint('Error saving purchase order: $e');
      rethrow;
    }
  }

  /// Save multiple purchase orders to the local database
  Future<void> savePurchaseOrders(
    List<Map<String, dynamic>> purchaseOrders,
  ) async {
    for (final order in purchaseOrders) {
      await savePurchaseOrder(order);
    }
  }

  /// Get a purchase order by ID
  Future<Map<String, dynamic>?> getPurchaseOrder(String orderId) async {
    if (_purchaseOrdersCollection == null) {
      await initialize();
    }

    try {
      final doc = await _purchaseOrdersCollection!.document(orderId);
      if (doc == null) return null;

      return doc.toPlainMap();
    } catch (e) {
      debugPrint('Error getting purchase order: $e');
      rethrow;
    }
  }

  /// Get all purchase orders
  Future<List<Map<String, dynamic>>> getAllPurchaseOrders() async {
    if (_purchaseOrdersCollection == null) {
      await initialize();
    }

    try {
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_purchaseOrdersCollection!));

      final resultSet = await query.execute();
      final results = <Map<String, dynamic>>[];

      await for (final result in resultSet.asStream()) {
        // Convert the result to a map
        final allResult = result.dictionary(0);
        if (allResult != null) {
          results.add(allResult.toPlainMap());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error getting all purchase orders: $e');
      return [];
    }
  }

  /// Update a purchase order
  Future<void> updatePurchaseOrder(
    String orderId,
    Map<String, dynamic> updatedOrder,
  ) async {
    if (_purchaseOrdersCollection == null) {
      await initialize();
    }

    debugPrint('Updating purchase order: $orderId');
    debugPrint('Updated order data: $updatedOrder');

    try {
      final doc = await _purchaseOrdersCollection!.document(orderId);
      if (doc == null) {
        debugPrint('Purchase order not found in database: $orderId');
        throw Exception('Purchase order not found: $orderId');
      }

      debugPrint('Existing document found: ${doc.id}');
      final mutableDoc = doc.toMutable();
      debugPrint('Original document data: ${doc.toPlainMap()}');

      // Update all properties
      updatedOrder.forEach((key, value) {
        debugPrint('Setting value for key: $key = $value');
        mutableDoc.setValue(value, key: key);
      });

      // Save the updated document
      await _purchaseOrdersCollection!.saveDocument(mutableDoc);
      debugPrint('Purchase order updated successfully: $orderId');

      // Verify the update by retrieving the document again
      final updatedDoc = await _purchaseOrdersCollection!.document(orderId);
      debugPrint('Updated document data: ${updatedDoc?.toPlainMap()}');
    } catch (e) {
      debugPrint('Error updating purchase order: $e');
      rethrow;
    }
  }

  /// Delete a purchase order
  Future<void> deletePurchaseOrder(String orderId) async {
    if (_purchaseOrdersCollection == null) {
      await initialize();
    }

    try {
      final doc = await _purchaseOrdersCollection!.document(orderId);
      if (doc != null) {
        await _purchaseOrdersCollection!.deleteDocument(doc);
        debugPrint('Purchase order deleted: $orderId');
      }
    } catch (e) {
      debugPrint('Error deleting purchase order: $e');
      rethrow;
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _purchaseOrdersCollection = null;
      debugPrint('Database closed');
    }
  }
}
