import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cbl/cbl.dart';
import 'database_service.dart';
import 'device_id_service.dart';

/// Service for managing GoodReceipt operations using local database
class GoodReceiptService {
  // Create an instance of the database service
  final DatabaseService _dbService = DatabaseService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  final Uuid _uuid = const Uuid();

  // Collection names
  static const String _goodReceiptsCollectionName = 'goodreceipts';
  static const String _goodReceiptItemsCollectionName = 'goodreceiptitems';

  // Database and collections
  Database? _database;
  Collection? _goodReceiptsCollection;
  Collection? _goodReceiptItemsCollection;

  // Singleton pattern
  static final GoodReceiptService _instance = GoodReceiptService._internal();

  factory GoodReceiptService() {
    return _instance;
  }

  GoodReceiptService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    if (_database != null) return; // Already initialized

    try {
      // Initialize the database service first
      await _dbService.initialize();

      // Open the database
      _database = await Database.openAsync('inventory_db');

      // Create or get collections
      _goodReceiptsCollection = await _getOrCreateCollection(
        _goodReceiptsCollectionName,
      );
      _goodReceiptItemsCollection = await _getOrCreateCollection(
        _goodReceiptItemsCollectionName,
      );

      debugPrint(
        'Collections created/opened: $_goodReceiptsCollectionName, $_goodReceiptItemsCollectionName',
      );
    } catch (e) {
      debugPrint('Error initializing good receipt collections: $e');
      rethrow;
    }
  }

  /// Get or create a collection
  Future<Collection> _getOrCreateCollection(String collectionName) async {
    if (_database == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Check if collection exists
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

      // Create new collection
      return await _database!.createCollection(collectionName);
    } catch (e) {
      debugPrint('Error creating collection: $e');
      rethrow;
    }
  }

  /// Get all good receipts
  Future<List<Map<String, dynamic>>> getGoodReceipts({
    Map<String, dynamic>? filter,
  }) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      // Build a query to get all receipts
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_goodReceiptsCollection!));

      // Apply filter if provided
      if (filter != null && filter.isNotEmpty) {
        ExpressionInterface? whereExpression;

        filter.forEach((key, value) {
          final condition = Expression.property(key).equalTo(Expression.value(value));
          if (whereExpression == null) {
            whereExpression = condition;
          } else {
            whereExpression = whereExpression!.and(condition);
          }
        });

        if (whereExpression != null) {
          query.where(whereExpression!);
        }
      }

      final resultSet = await query.execute();
      final results = <Map<String, dynamic>>[];

      await for (final result in resultSet.asStream()) {
        final allResult = result.dictionary(0);
        if (allResult != null) {
          final receipt = allResult.toPlainMap();
          final receiptId = receipt['id'] as String;

          // Get items for this receipt
          final items = await getGoodReceiptItems(receiptId);
          receipt['items'] = items;

          results.add(receipt);
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching good receipts: $e');
      return [];
    }
  }

  /// Create a new good receipt
  Future<Map<String, dynamic>> createGoodReceipt({
    required String name,
    required int status,
    required String supplierCode,
    required String whs,
    String? delDate,
  }) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      final now = DateTime.now().toIso8601String();
      final id = _uuid.v4();

      final goodReceipt = {
        'id': id,
        'name': name,
        'status': status,
        'supplierCode': supplierCode,
        'whs': whs,
        'delDate': delDate,
        'createdAt': now,
        'updatedAt': now,
      };

      // Create a document
      final doc = MutableDocument.withId(id);

      // Add all properties from the good receipt
      goodReceipt.forEach((key, value) {
        doc.setValue(value, key: key);
      });

      // Save the document to the collection
      await _goodReceiptsCollection!.saveDocument(doc);
      debugPrint('Good receipt created: $id');

      // Add empty items list for return value
      goodReceipt['items'] = [];

      return goodReceipt;
    } catch (e) {
      debugPrint('Error creating good receipt: $e');
      rethrow;
    }
  }

  /// Get a good receipt by ID
  Future<Map<String, dynamic>?> getGoodReceipt(String id) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      final doc = await _goodReceiptsCollection!.document(id);
      if (doc == null) return null;

      final receipt = doc.toPlainMap();

      // Get items for this receipt
      final items = await getGoodReceiptItems(id);
      receipt['items'] = items;

      return receipt;
    } catch (e) {
      debugPrint('Error getting good receipt: $e');
      return null;
    }
  }

  /// Update a good receipt
  Future<Map<String, dynamic>> updateGoodReceipt({
    required String id,
    String? name,
    int? status,
    String? supplierCode,
    String? whs,
    String? delDate,
  }) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      final doc = await _goodReceiptsCollection!.document(id);
      if (doc == null) {
        throw Exception('Good receipt not found: $id');
      }

      final mutableDoc = doc.toMutable();

      // Update fields
      mutableDoc.setValue(DateTime.now().toIso8601String(), key: 'updatedAt');

      if (name != null) mutableDoc.setValue(name, key: 'name');
      if (status != null) mutableDoc.setValue(status, key: 'status');
      if (supplierCode != null)
        mutableDoc.setValue(supplierCode, key: 'supplierCode');
      if (whs != null) mutableDoc.setValue(whs, key: 'whs');
      if (delDate != null) mutableDoc.setValue(delDate, key: 'delDate');

      // Save the updated document
      await _goodReceiptsCollection!.saveDocument(mutableDoc);
      debugPrint('Good receipt updated: $id');

      // Get the updated receipt with items
      final updatedReceipt = await getGoodReceipt(id);
      if (updatedReceipt == null) {
        throw Exception('Failed to retrieve updated good receipt');
      }

      return updatedReceipt;
    } catch (e) {
      debugPrint('Error updating good receipt: $e');
      rethrow;
    }
  }

  /// Delete a good receipt
  Future<bool> deleteGoodReceipt(String id) async {
    if (_goodReceiptsCollection == null ||
        _goodReceiptItemsCollection == null) {
      await initialize();
    }

    try {
      // First delete all items for this receipt
      final items = await getGoodReceiptItems(id);
      for (final item in items) {
        final itemId = item['id'] as String;
        await deleteGoodReceiptItem(itemId);
      }

      // Then delete the receipt itself
      final doc = await _goodReceiptsCollection!.document(id);
      if (doc != null) {
        await _goodReceiptsCollection!.deleteDocument(doc);
        debugPrint('Good receipt deleted: $id');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting good receipt: $e');
      return false;
    }
  }

  /// Get items for a specific good receipt
  Future<List<Map<String, dynamic>>> getGoodReceiptItems(
    String receiptId,
  ) async {
    if (_goodReceiptItemsCollection == null) {
      await initialize();
    }

    try {
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_goodReceiptItemsCollection!));

      // Add filter for specific receipt if provided
      if (receiptId.isNotEmpty) {
        query.where(
          Expression.property(
            'goodReceiptId',
          ).equalTo(Expression.string(receiptId)),
        );
      }

      final resultSet = await query.execute();
      final results = <Map<String, dynamic>>[];

      await for (final result in resultSet.asStream()) {
        final allResult = result.dictionary(0);
        if (allResult != null) {
          results.add(allResult.toPlainMap());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error getting good receipt items: $e');
      return [];
    }
  }

  /// Create a good receipt item
  Future<Map<String, dynamic>> createGoodReceiptItem({
    required String goodReceiptId,
    required String itemCode,
    required String name,
    required double qty,
    required double price,
    required String uom,
    String? deviceId,
  }) async {
    if (_goodReceiptItemsCollection == null ||
        _goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      final id = _uuid.v4();
      final actualDeviceId = deviceId ?? await _deviceIdService.getDeviceId();

      final item = {
        'id': id,
        'goodReceiptId': goodReceiptId,
        'itemCode': itemCode,
        'name': name,
        'qty': qty,
        'price': price,
        'uom': uom,
        'deviceId': actualDeviceId,
      };

      // Create a document
      final doc = MutableDocument.withId(id);

      // Add all properties from the item
      item.forEach((key, value) {
        doc.setValue(value, key: key);
      });

      // Save the document to the collection
      await _goodReceiptItemsCollection!.saveDocument(doc);
      debugPrint('Good receipt item created: $id');

      // Update the receipt's updatedAt timestamp
      final receiptDoc = await _goodReceiptsCollection!.document(goodReceiptId);
      if (receiptDoc != null) {
        final mutableReceiptDoc = receiptDoc.toMutable();
        mutableReceiptDoc.setValue(
          DateTime.now().toIso8601String(),
          key: 'updatedAt',
        );
        await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
      }

      return item;
    } catch (e) {
      debugPrint('Error creating good receipt item: $e');
      rethrow;
    }
  }

  /// Update a good receipt item
  Future<Map<String, dynamic>> updateGoodReceiptItem({
    required String id,
    String? itemCode,
    String? name,
    double? qty,
    double? price,
    String? uom,
    String? deviceId,
  }) async {
    if (_goodReceiptItemsCollection == null ||
        _goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      // Get the item document
      final doc = await _goodReceiptItemsCollection!.document(id);
      if (doc == null) {
        throw Exception('Good receipt item not found: $id');
      }

      final mutableDoc = doc.toMutable();
      final item = doc.toPlainMap();
      final goodReceiptId = item['goodReceiptId'] as String;

      // Update fields
      if (itemCode != null) mutableDoc.setValue(itemCode, key: 'itemCode');
      if (name != null) mutableDoc.setValue(name, key: 'name');
      if (qty != null) mutableDoc.setValue(qty, key: 'qty');
      if (price != null) mutableDoc.setValue(price, key: 'price');
      if (uom != null) mutableDoc.setValue(uom, key: 'uom');
      if (deviceId != null) mutableDoc.setValue(deviceId, key: 'deviceId');

      // Save the updated document
      await _goodReceiptItemsCollection!.saveDocument(mutableDoc);
      debugPrint('Good receipt item updated: $id');

      // Update the receipt's updatedAt timestamp
      final receiptDoc = await _goodReceiptsCollection!.document(goodReceiptId);
      if (receiptDoc != null) {
        final mutableReceiptDoc = receiptDoc.toMutable();
        mutableReceiptDoc.setValue(
          DateTime.now().toIso8601String(),
          key: 'updatedAt',
        );
        await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
      }

      // Return the updated item
      final updatedDoc = await _goodReceiptItemsCollection!.document(id);
      if (updatedDoc == null) {
        throw Exception('Failed to retrieve updated item');
      }

      return updatedDoc.toPlainMap();
    } catch (e) {
      debugPrint('Error updating good receipt item: $e');
      rethrow;
    }
  }

  /// Delete a good receipt item
  Future<bool> deleteGoodReceiptItem(String id) async {
    if (_goodReceiptItemsCollection == null ||
        _goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      // Get the item to find its receipt ID before deleting
      final doc = await _goodReceiptItemsCollection!.document(id);
      if (doc == null) {
        // Item not found, consider it already deleted
        return true;
      }

      final item = doc.toPlainMap();
      final goodReceiptId = item['goodReceiptId'] as String;

      // Delete the item
      await _goodReceiptItemsCollection!.deleteDocument(doc);
      debugPrint('Good receipt item deleted: $id');

      // Update the receipt's updatedAt timestamp
      final receiptDoc = await _goodReceiptsCollection!.document(goodReceiptId);
      if (receiptDoc != null) {
        final mutableReceiptDoc = receiptDoc.toMutable();
        mutableReceiptDoc.setValue(
          DateTime.now().toIso8601String(),
          key: 'updatedAt',
        );
        await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting good receipt item: $e');
      return false;
    }
  }
}
