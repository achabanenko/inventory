import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cbl/cbl.dart';
import 'database_service.dart';
import 'device_id_service.dart';
import 'graphql_service.dart' as gql;

/// Service for managing GoodReceipt operations using local database and server integration
class GoodReceiptService {
  // Create an instance of the database service
  final DatabaseService _dbService = DatabaseService();
  final DeviceIdService _deviceIdService = DeviceIdService();
  final Uuid _uuid = const Uuid();
  final gql.GoodReceiptService _graphQLGoodReceiptService =
      gql.GoodReceiptService();

  // Collection names
  static const String _goodReceiptsCollectionName = 'goodreceipts';
  static const String _goodReceiptItemsCollectionName = 'goodreceiptitems';
  static const String _warehouseCollectionName = 'warehouses';
  static const String _supplierCollectionName = 'suppliers';

  // Database and collections
  Database? _database;
  Collection? _goodReceiptsCollection;
  Collection? _goodReceiptItemsCollection;
  Collection? _warehouseCollection;
  Collection? _supplierCollection;

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
      _warehouseCollection = await _getOrCreateCollection(
        _warehouseCollectionName,
      );
      _supplierCollection = await _getOrCreateCollection(
        _supplierCollectionName,
      );

      debugPrint(
        'Collections created/opened: $_goodReceiptsCollectionName, $_goodReceiptItemsCollectionName, $_warehouseCollectionName, $_supplierCollectionName',
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

  /// Get all good receipts from both local database and server
  /// If fetchItemsFromServer is true, it will fetch items for each receipt from the server
  Future<List<Map<String, dynamic>>> getGoodReceipts({
    Map<String, dynamic>? filter,
    bool fetchFromServer = true, // Add parameter to control server fetching
    bool fetchItemsFromServer = true, // Add parameter to control fetching items
  }) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    debugPrint('Fetching good receipts (fetchFromServer: $fetchFromServer)');
    final results = <Map<String, dynamic>>[];
    final localIds = <String>{}; // Track local IDs to avoid duplicates

    try {
      // 1. First get local receipts
      debugPrint('Fetching receipts from local database');
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_goodReceiptsCollection!));

      // Apply filter if provided
      if (filter != null && filter.isNotEmpty) {
        ExpressionInterface? whereExpression;

        filter.forEach((key, value) {
          final condition = Expression.property(
            key,
          ).equalTo(Expression.value(value));
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

      await for (final result in resultSet.asStream()) {
        final allResult = result.dictionary(0);
        if (allResult != null) {
          final receipt = allResult.toPlainMap();
          final receiptId = receipt['id'] as String;
          localIds.add(receiptId);

          // Get items for this receipt
          final items = await getGoodReceiptItems(receiptId);
          receipt['items'] = items;

          results.add(receipt);
        }
      }

      debugPrint('Found ${results.length} local receipts');

      // 2. Then try to get server receipts if requested
      if (fetchFromServer) {
        try {
          debugPrint('Fetching receipts from server');
          final serverReceipts = await _graphQLGoodReceiptService
              .getGoodReceipts(filter: filter);
          debugPrint('Found ${serverReceipts.length} server receipts');

          // Process server receipts
          for (final serverReceipt in serverReceipts) {
            final serverId = serverReceipt['id'] as String;

            // Check if we already have this receipt locally
            if (!localIds.contains(serverId)) {
              debugPrint(
                'Adding server receipt $serverId to results (not in local DB)',
              );
              
              // Add server items to the receipt if needed
              if (fetchItemsFromServer) {
                try {
                  final serverItems = await _graphQLGoodReceiptService
                      .getGoodReceiptItems(serverId);
                  serverReceipt['items'] = serverItems;
                } catch (e) {
                  debugPrint(
                    'Error fetching items for server receipt $serverId: $e',
                  );
                  serverReceipt['items'] = [];
                }
              } else {
                // Just set an empty array for items when not fetching them
                serverReceipt['items'] = [];
              }

              // Add to results
              results.add(serverReceipt);

              // Save to local database for future use
              try {
                await _saveServerReceiptLocally(serverReceipt);
              } catch (e) {
                debugPrint('Error saving server receipt locally: $e');
              }
            } else {
              debugPrint('Server receipt $serverId already exists locally');
            }
          }
        } catch (e) {
          debugPrint('Error fetching receipts from server: $e');
          // Continue with local results only
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching good receipts: $e');
      return [];
    }
  }

  /// Save a server receipt to the local database
  Future<void> _saveServerReceiptLocally(
    Map<String, dynamic> serverReceipt,
  ) async {
    if (_goodReceiptsCollection == null) {
      await initialize();
    }

    try {
      final id = serverReceipt['id'] as String;

      // Check if receipt already exists locally
      final existingDoc = await _goodReceiptsCollection!.document(id);
      if (existingDoc != null) {
        debugPrint('Receipt $id already exists locally, updating');
        // Update existing document
        final mutableDoc = existingDoc.toMutable();

        // Update all fields from server receipt
        serverReceipt.forEach((key, value) {
          if (key != 'items') {
            // Handle items separately
            mutableDoc.setValue(value, key: key);
          }
        });

        // Mark as synced with server
        mutableDoc.setValue(true, key: 'syncedWithServer');

        await _goodReceiptsCollection!.saveDocument(mutableDoc);
      } else {
        debugPrint('Creating new local receipt from server data: $id');
        // Create new document
        final doc = MutableDocument.withId(id);

        // Add all properties from server receipt
        serverReceipt.forEach((key, value) {
          if (key != 'items') {
            // Handle items separately
            doc.setValue(value, key: key);
          }
        });

        // Mark as synced with server
        doc.setValue(true, key: 'syncedWithServer');

        await _goodReceiptsCollection!.saveDocument(doc);
      }

      // Handle items if present
      if (serverReceipt.containsKey('items') &&
          serverReceipt['items'] is List) {
        final items = serverReceipt['items'] as List;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            await _saveServerItemLocally(item, id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving server receipt locally: $e');
      rethrow;
    }
  }

  /// Save a server item to the local database
  Future<void> _saveServerItemLocally(
    Map<String, dynamic> serverItem,
    String receiptId,
  ) async {
    if (_goodReceiptItemsCollection == null) {
      await initialize();
    }

    try {
      final id = serverItem['id'] as String;

      // Check if item already exists locally
      final existingDoc = await _goodReceiptItemsCollection!.document(id);
      if (existingDoc != null) {
        debugPrint('Item $id already exists locally, updating');
        // Update existing document
        final mutableDoc = existingDoc.toMutable();

        // Update all fields from server item
        serverItem.forEach((key, value) {
          mutableDoc.setValue(value, key: key);
        });

        // Ensure receipt ID is set correctly
        mutableDoc.setValue(receiptId, key: 'goodReceiptId');

        // Mark as synced with server
        mutableDoc.setValue(true, key: 'syncedWithServer');

        await _goodReceiptItemsCollection!.saveDocument(mutableDoc);
      } else {
        debugPrint('Creating new local item from server data: $id');
        // Create new document
        final doc = MutableDocument.withId(id);

        // Add all properties from server item
        serverItem.forEach((key, value) {
          doc.setValue(value, key: key);
        });

        // Ensure receipt ID is set correctly
        doc.setValue(receiptId, key: 'goodReceiptId');

        // Mark as synced with server
        doc.setValue(true, key: 'syncedWithServer');

        await _goodReceiptItemsCollection!.saveDocument(doc);
      }
    } catch (e) {
      debugPrint('Error saving server item locally: $e');
      // Continue with other items
    }
  }

  /// Create a new good receipt locally and on the server
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
      // First create the receipt on the server
      Map<String, dynamic>? serverReceipt;
      late String id;
      late String createdAt;
      late String updatedAt;
      bool syncedWithServer = false;

      try {
        // Create receipt on the server
        serverReceipt = await _graphQLGoodReceiptService.createGoodReceipt(
          name: name,
          status: status,
          supplierCode: supplierCode,
          whs: whs,
          delDate: delDate,
        );

        // Get ID and timestamps from server
        id = serverReceipt['id'] as String;
        createdAt = serverReceipt['createdAt'] as String;
        updatedAt = serverReceipt['updatedAt'] as String;
        syncedWithServer = true;

        debugPrint('Good receipt created on server: $id');
      } catch (serverError) {
        // If server creation fails, generate a local ID and timestamps
        debugPrint('Failed to create receipt on server: $serverError');
        id = _uuid.v4();
        final now = DateTime.now().toIso8601String();
        createdAt = now;
        updatedAt = now;
      }

      final goodReceipt = {
        'id': id,
        'name': name,
        'status': status,
        'supplierCode': supplierCode,
        'whs': whs,
        'delDate': delDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'syncedWithServer': syncedWithServer,
      };

      // Create a document
      final doc = MutableDocument.withId(id);

      // Add all properties from the good receipt
      goodReceipt.forEach((key, value) {
        doc.setValue(value, key: key);
      });

      // Save the document to the collection
      await _goodReceiptsCollection!.saveDocument(doc);
      debugPrint('Good receipt created locally: $id');

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
      debugPrint('Getting good receipt with ID: $id');
      final doc = await _goodReceiptsCollection!.document(id);
      if (doc == null) {
        debugPrint('No receipt document found with ID: $id');
        return null;
      }

      final receipt = doc.toPlainMap();
      debugPrint('Found receipt: ${receipt['name']}');

      // Get items for this receipt
      final allItems = await getGoodReceiptItems(id);
      debugPrint('Found ${allItems.length} items for receipt $id');
      
      // Filter out deleted items
      final nonDeletedItems = allItems.where((item) => item['deleted'] != true).toList();
      debugPrint('After filtering, ${nonDeletedItems.length} non-deleted items remain');
      
      // Log each non-deleted item for debugging
      for (int i = 0; i < nonDeletedItems.length; i++) {
        debugPrint('Non-deleted item $i: ${nonDeletedItems[i]['itemCode']} - ${nonDeletedItems[i]['name']}');
      }
      
      receipt['items'] = nonDeletedItems;

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
      if (supplierCode != null) {
        mutableDoc.setValue(supplierCode, key: 'supplierCode');
      }
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
      debugPrint('Querying items for receipt ID: $receiptId');
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_goodReceiptItemsCollection!));

      // Add filter for specific receipt if provided
      if (receiptId.isNotEmpty) {
        // Create a compound expression to filter by receipt ID and exclude deleted items
        final receiptIdExpr = Expression.property('goodReceiptId').equalTo(Expression.string(receiptId));
        
        // Add condition to filter out deleted items
        final notDeletedExpr = Expression.property('deleted').notEqualTo(Expression.boolean(true));
        
        // Combine the expressions with AND
        query.where(receiptIdExpr.and(notDeletedExpr));
        
        debugPrint('Added filter for goodReceiptId = $receiptId and not deleted');
      }

      final resultSet = await query.execute();
      final results = <Map<String, dynamic>>[];

      await for (final result in resultSet.asStream()) {
        final allResult = result.dictionary(0);
        if (allResult != null) {
          final item = allResult.toPlainMap();
          results.add(item);
          debugPrint('Found item: ${item['itemCode']} - ${item['name']}');
        }
      }

      debugPrint('Found ${results.length} items for receipt $receiptId');
      return results;
    } catch (e) {
      debugPrint('Error getting good receipt items: $e');
      return [];
    }
  }

  /// Create a good receipt item locally
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

      // Create the item with proper types
      final item = {
        'id': id,
        'goodReceiptId': goodReceiptId,
        'itemCode': itemCode,
        'name': name,
        'qty': qty,  // Ensure this is a double
        'price': price,  // Ensure this is a double
        'uom': uom,
        'deviceId': actualDeviceId,
        'syncedWithServer': false,
      };
      
      // Debug log to verify data types
      debugPrint('Creating item with qty type: ${qty.runtimeType}, price type: ${price.runtimeType}');

      // Create a document
      final doc = MutableDocument.withId(id);

      // Add all properties from the item
      item.forEach((key, value) {
        doc.setValue(value, key: key);
      });

      // Save the document to the collection
      await _goodReceiptItemsCollection!.saveDocument(doc);
      debugPrint('Good receipt item created locally: $id for receipt: $goodReceiptId');
      
      // Verify the item was saved by retrieving it
      final savedDoc = await _goodReceiptItemsCollection!.document(id);
      if (savedDoc != null) {
        debugPrint('Successfully verified item was saved with ID: $id');
      } else {
        debugPrint('WARNING: Could not verify item was saved with ID: $id');
      }

      // Update the receipt's updatedAt timestamp
      final receiptDoc = await _goodReceiptsCollection!.document(goodReceiptId);
      if (receiptDoc != null) {
        final mutableReceiptDoc = receiptDoc.toMutable();
        mutableReceiptDoc.setValue(
          DateTime.now().toIso8601String(),
          key: 'updatedAt',
        );

        // Mark receipt as having unsynchronized changes
        mutableReceiptDoc.setValue(false, key: 'syncedWithServer');

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
      
      // Check if the item has been synced with the server
      final bool syncedWithServer = item['syncedWithServer'] == true;
      
      if (syncedWithServer) {
        // If the item is already on the server, mark it as deleted instead of actually deleting it
        // This way we can track it and delete it from the server during the next sync
        final mutableItemDoc = doc.toMutable();
        mutableItemDoc.setValue(true, key: 'deleted');
        mutableItemDoc.setValue(false, key: 'syncedWithServer'); // Need to sync this deletion
        mutableItemDoc.setValue(DateTime.now().toIso8601String(), key: 'deletedAt');
        
        // IMPORTANT: Store the server ID if it exists (this is the ID we need to delete on the server)
        // First check if we already have a serverId stored
        if (item.containsKey('serverId') && item['serverId'] != null) {
          // Keep the existing serverId
          debugPrint('Keeping existing server ID ${item['serverId']} for deleted item');
        } else if (item.containsKey('id')) {
          // If no serverId but we have an id, use that (for items created on server)
          mutableItemDoc.setValue(item['id'], key: 'serverId');
          debugPrint('Stored server ID ${item['id']} for deleted item');
        }
        
        await _goodReceiptItemsCollection!.saveDocument(mutableItemDoc);
        debugPrint('Good receipt item marked as deleted: $id');
      } else {
        // If the item hasn't been synced with the server yet, we can safely delete it
        await _goodReceiptItemsCollection!.deleteDocument(doc);
        debugPrint('Good receipt item deleted (was never synced): $id');
      }

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

  /// Create a warehouse
  Future<Map<String, dynamic>> createWarehouse({
    required String code,
    required String name,
  }) async {
    if (_warehouseCollection == null) {
      await initialize();
    }

    try {
      // Check if a warehouse with the same code already exists
      final existingWarehouses = await getWarehouses(filter: {'code': code});
      if (existingWarehouses.isNotEmpty) {
        throw Exception('A warehouse with code $code already exists');
      }

      // Create a document
      final doc = MutableDocument.withId(code);

      // Set properties
      doc.setValue(code, key: 'code');
      doc.setValue(name, key: 'name');
      doc.setValue(DateTime.now().toIso8601String(), key: 'createdAt');

      // Save to database
      await _warehouseCollection!.saveDocument(doc);

      return {'code': code, 'name': name, 'createdAt': doc.string('createdAt')};
    } catch (e) {
      debugPrint('Error creating warehouse: $e');
      rethrow;
    }
  }

  /// Get all warehouses
  Future<List<Map<String, dynamic>>> getWarehouses({
    Map<String, dynamic>? filter,
  }) async {
    if (_warehouseCollection == null) {
      await initialize();
    }

    try {
      // Build a query to get all warehouses
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_warehouseCollection!));

      // Apply filter if provided
      if (filter != null && filter.isNotEmpty) {
        ExpressionInterface? whereExpression;

        filter.forEach((key, value) {
          final condition = Expression.property(
            key,
          ).equalTo(Expression.value(value));
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
          results.add(allResult.toPlainMap());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error getting warehouses: $e');
      rethrow;
    }
  }

  /// Create a supplier
  Future<Map<String, dynamic>> createSupplier({
    required String code,
    required String name,
  }) async {
    if (_supplierCollection == null) {
      await initialize();
    }

    try {
      // Check if a supplier with the same code already exists
      final existingSuppliers = await getSuppliers(filter: {'code': code});
      if (existingSuppliers.isNotEmpty) {
        throw Exception('A supplier with code $code already exists');
      }

      // Create a document
      final doc = MutableDocument.withId(code);

      // Set properties
      doc.setValue(code, key: 'code');
      doc.setValue(name, key: 'name');
      doc.setValue(DateTime.now().toIso8601String(), key: 'createdAt');

      // Save to database
      await _supplierCollection!.saveDocument(doc);

      return {'code': code, 'name': name, 'createdAt': doc.string('createdAt')};
    } catch (e) {
      debugPrint('Error creating supplier: $e');
      rethrow;
    }
  }

  /// Get all suppliers
  Future<List<Map<String, dynamic>>> getSuppliers({
    Map<String, dynamic>? filter,
  }) async {
    if (_supplierCollection == null) {
      await initialize();
    }

    try {
      // Build a query to get all suppliers
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_supplierCollection!));

      // Apply filter if provided
      if (filter != null && filter.isNotEmpty) {
        ExpressionInterface? whereExpression;

        filter.forEach((key, value) {
          final condition = Expression.property(
            key,
          ).equalTo(Expression.value(value));
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
          results.add(allResult.toPlainMap());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error getting suppliers: $e');
      rethrow;
    }
  }

  /// Fetch good receipts only from the server
  /// This is used by the goods receipt list page
  /// If fetchItems is true, it will fetch complete receipts with items
  /// If fetchItems is false (default), it will fetch only headers for efficiency
  Future<List<Map<String, dynamic>>> fetchServerGoodReceipts({bool fetchItems = false}) async {
    debugPrint('Fetching good receipts from server only (fetchItems: $fetchItems)');
    try {
      // Initialize if needed
      await initialize();

      // Fetch from server - use optimized query for list view
      final List<Map<String, dynamic>> serverReceipts;
      if (fetchItems) {
        // Fetch complete receipts with items (slower, more data)
        serverReceipts = await _graphQLGoodReceiptService.getGoodReceipts();
        debugPrint('Found ${serverReceipts.length} server good receipts with items');
      } else {
        // Fetch only headers (faster, less data) - better for list views
        serverReceipts = await _graphQLGoodReceiptService.getGoodReceiptHeaders();
        debugPrint('Found ${serverReceipts.length} server good receipt headers');
        
        // Add empty items array to each receipt
        for (final receipt in serverReceipts) {
          receipt['items'] = [];
        }
      }

      // If we have receipts, truncate local database and save new ones
      debugPrint('Updating local database with server data...');
      await _truncateLocalGoodReceipts();

      // Save server receipts to local database in the background
      _saveServerReceiptsInBackground(serverReceipts);

      return serverReceipts;
    } catch (e) {
      debugPrint('Error fetching good receipts from server: $e');
      rethrow;
    }
  }

  /// Truncate local good receipts collection
  /// This is called when server returns empty list
  Future<void> _truncateLocalGoodReceipts() async {
    try {
      if (_goodReceiptsCollection == null) {
        await initialize();
      }

      // Get all local receipts
      final query = QueryBuilder()
          .select(SelectResult.expression(Meta.id))
          .from(DataSource.collection(_goodReceiptsCollection!));

      final resultSet = await query.execute();
      int deletedCount = 0;

      await for (final result in resultSet.asStream()) {
        final id = result.string(0);
        if (id != null) {
          // Delete the document by ID
          final doc = MutableDocument.withId(id);
          await _goodReceiptsCollection!.deleteDocument(doc);
          deletedCount++;
        }
      }

      debugPrint('Truncated $deletedCount local good receipts');
    } catch (e) {
      debugPrint('Error truncating local good receipts: $e');
      // Don't rethrow as this is a cleanup operation
    }
  }

  /// Save server receipts to local database in the background
  /// This is done asynchronously to not block the UI
  Future<void> _saveServerReceiptsInBackground(
    List<Map<String, dynamic>> serverReceipts,
  ) async {
    try {
      for (final serverReceipt in serverReceipts) {
        await _saveServerReceiptLocally(serverReceipt);
      }
      debugPrint(
        'Finished saving ${serverReceipts.length} server receipts to local database',
      );
    } catch (e) {
      debugPrint('Error saving server receipts to local database: $e');
      // Don't rethrow as this is a background operation
    }
  }

  /// Fetch a single good receipt with all its items from the server
  Future<Map<String, dynamic>?> fetchSingleGoodReceiptWithItems(String id) async {
    debugPrint('Fetching single good receipt with items from server: $id');
    try {
      // Initialize if needed
      await initialize();
      
      // Fetch the receipt with items from server
      final receipts = await _graphQLGoodReceiptService.getGoodReceipts(
        filter: {'id': id},
      );
      
      if (receipts.isEmpty) {
        debugPrint('Receipt not found on server: $id');
        return null;
      }
      
      final receipt = receipts.first;
      
      // Save to local database in background
      _saveServerReceiptLocally(receipt).then((_) {
        debugPrint('Saved receipt $id from server to local database');
      }).catchError((e) {
        debugPrint('Error saving receipt $id from server to local database: $e');
      });
      
      return receipt;
    } catch (e) {
      debugPrint('Error fetching single receipt from server: $e');
      rethrow;
    }
  }
  
  /// Push local changes for a good receipt to the server
  Future<bool> pushGoodReceiptToServer(String receiptId) async {
    if (_goodReceiptsCollection == null ||
        _goodReceiptItemsCollection == null) {
      await initialize();
    }

    debugPrint('Starting push to server for receipt: $receiptId');

    try {
      // Get the receipt from local database
      final receiptDoc = await _goodReceiptsCollection!.document(receiptId);
      if (receiptDoc == null) {
        debugPrint(
          'Error: Good receipt not found in local database: $receiptId',
        );
        throw Exception('Good receipt not found: $receiptId');
      }

      final receipt = receiptDoc.toPlainMap();
      debugPrint('Found local receipt: ${receipt.toString()}');

      // Check if the receipt exists on the server
      bool receiptExistsOnServer = receipt['syncedWithServer'] == true;
      debugPrint('Receipt exists on server: $receiptExistsOnServer');

      // Variable to store the server receipt ID (may be different from local ID)
      String serverReceiptId = receiptId;

      if (!receiptExistsOnServer) {
        // Create the receipt on the server
        try {
          debugPrint(
            'Attempting to create receipt on server with: name=${receipt['name']}, status=${receipt['status']}, supplierCode=${receipt['supplierCode']}, whs=${receipt['whs']}',
          );

          final serverReceipt = await _graphQLGoodReceiptService
              .createGoodReceipt(
                name: receipt['name'] as String,
                status: receipt['status'] as int,
                supplierCode: receipt['supplierCode'] as String,
                whs: receipt['whs'] as String,
                delDate: receipt['delDate'] as String?,
              );

          debugPrint('Server receipt created: ${serverReceipt.toString()}');

          // Store the server receipt ID for use with items
          serverReceiptId = serverReceipt['id'] as String;
          debugPrint('Using server receipt ID: $serverReceiptId for items');

          // Update the local receipt with the server ID if different
          if (serverReceiptId != receiptId) {
            debugPrint(
              'Server ID ($serverReceiptId) different from local ID ($receiptId)',
            );
            // Store server ID in the local receipt for reference
            final mutableReceiptDoc = receiptDoc.toMutable();
            mutableReceiptDoc.setValue(true, key: 'syncedWithServer');
            mutableReceiptDoc.setValue(serverReceiptId, key: 'serverId');
            await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
          } else {
            // Mark as synced
            debugPrint('Marking receipt as synced with server');
            final mutableReceiptDoc = receiptDoc.toMutable();
            mutableReceiptDoc.setValue(true, key: 'syncedWithServer');
            await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
          }

          receiptExistsOnServer = true;
        } catch (e) {
          debugPrint('Error creating receipt on server: $e');
          return false;
        }
      } else {
        // If receipt already exists on server, check if we have a stored server ID
        if (receipt.containsKey('serverId') && receipt['serverId'] != null) {
          serverReceiptId = receipt['serverId'] as String;
          debugPrint('Using stored server ID: $serverReceiptId for items');
        }
      }

      // Get all items for this receipt, including deleted ones that need to be synced
      // We need to use a special query to include deleted items
      final query = QueryBuilder()
          .select(SelectResult.all())
          .from(DataSource.collection(_goodReceiptItemsCollection!));
      
      // Add filter for specific receipt
      final receiptIdExpr = Expression.property('goodReceiptId').equalTo(Expression.string(receiptId));
      query.where(receiptIdExpr);
      
      final resultSet = await query.execute();
      final items = <Map<String, dynamic>>[];
      
      await for (final result in resultSet.asStream()) {
        final allResult = result.dictionary(0);
        if (allResult != null) {
          final item = allResult.toPlainMap();
          items.add(item);
        }
      }
      
      debugPrint('Found ${items.length} items to push to server (including deleted items)');

      // Push each unsynchronized item to the server
      int successCount = 0;
      int deletedCount = 0;
      
      // Process all items in two passes: first handle deletions, then handle additions/updates
      // This ensures we process all deletions first
      
      // PASS 1: Process all deleted items
      debugPrint('PASS 1: Processing deleted items');
      for (final item in items) {
        final bool isDeleted = item['deleted'] == true;
        
        if (!isDeleted) continue; // Skip non-deleted items in this pass
        
        debugPrint('Processing deleted item ${item['id']} - ${item['itemCode']}');
        
        // Log all keys in the item for debugging
        for (final key in item.keys) {
          debugPrint('  $key: ${item[key]}');
        }
        
        // Check if this item has a server ID
        if (item.containsKey('serverId') && item['serverId'] != null) {
          final String serverItemId = item['serverId'] as String;
          debugPrint('Attempting to delete item $serverItemId from server');
          
          try {
            // Call the server API to delete the item
            final deleteSuccess = await _graphQLGoodReceiptService.deleteGoodReceiptItem(serverItemId);
            
            if (deleteSuccess) {
              debugPrint('Item with server ID $serverItemId successfully deleted from server');
              deletedCount++;
              
              // Now we can safely delete it from local database
              final itemDoc = await _goodReceiptItemsCollection!.document(item['id']);
              if (itemDoc != null) {
                await _goodReceiptItemsCollection!.deleteDocument(itemDoc);
                debugPrint('Deleted item ${item['id']} from local database after server sync');
              }
            } else {
              debugPrint('Failed to delete item with server ID $serverItemId from server');
              // Keep the item marked as deleted but not synced so we can try again later
            }
          } catch (deleteError) {
            debugPrint('Error deleting item from server: $deleteError');
          }
        } else {
          // Item was marked for deletion but has no server ID, just delete locally
          final itemDoc = await _goodReceiptItemsCollection!.document(item['id']);
          if (itemDoc != null) {
            await _goodReceiptItemsCollection!.deleteDocument(itemDoc);
            debugPrint('Deleted item ${item['id']} from local database (no server ID)');
          }
        }
      }
      
      // PASS 2: Process all non-deleted items that need syncing
      debugPrint('PASS 2: Processing non-deleted items');
      for (final item in items) {
        final bool isDeleted = item['deleted'] == true;
        final bool needsSync = item['syncedWithServer'] != true;
        
        if (isDeleted) continue; // Skip deleted items in this pass
        if (!needsSync) continue; // Skip already synced items
        
        debugPrint('Processing non-deleted item ${item['id']} - ${item['itemCode']} for sync');
        
        try {
          // Regular item creation/update
          debugPrint(
            'Pushing item ${item['id']} to server with receipt ID: $serverReceiptId',
          );
          // Create the item on the server using the SERVER receipt ID
          final serverItem = await _graphQLGoodReceiptService
              .createGoodReceiptItem(
                goodReceiptId: serverReceiptId, // Use server receipt ID here
                itemCode: item['itemCode'] as String,
                name: item['name'] as String,
                qty: (item['qty'] as num).toDouble(),
                price: (item['price'] as num).toDouble(),
                uom: item['uom'] as String,
                deviceId: item['deviceId'] as String?,
              );

          debugPrint(
            'Item successfully pushed to server: ${serverItem.toString()}',
          );
          successCount++;

          // Mark the item as synced
          final itemDoc = await _goodReceiptItemsCollection!.document(
            item['id'],
          );
          if (itemDoc != null) {
            final mutableItemDoc = itemDoc.toMutable();
            mutableItemDoc.setValue(true, key: 'syncedWithServer');
            mutableItemDoc.setValue(serverItem['id'], key: 'serverId');
            await _goodReceiptItemsCollection!.saveDocument(mutableItemDoc);
          }
        } catch (e) {
          debugPrint('Error processing item with server: $e');
          // Continue with other items even if one fails
        }
      }
      
      debugPrint('Successfully pushed $successCount items to server and deleted $deletedCount items');

      if (successCount == 0 && deletedCount == 0 && items.isNotEmpty) {
        debugPrint('Warning: No items were successfully pushed to or deleted from the server');
      }

      // Update the receipt as synced
      final updatedReceiptDoc = await _goodReceiptsCollection!.document(
        receiptId,
      );
      if (updatedReceiptDoc != null) {
        final mutableReceiptDoc = updatedReceiptDoc.toMutable();
        mutableReceiptDoc.setValue(true, key: 'syncedWithServer');
        await _goodReceiptsCollection!.saveDocument(mutableReceiptDoc);
      }

      return true;
    } catch (e) {
      debugPrint('Error pushing good receipt to server: $e');
      return false;
    }
  }
  /// Check if a good receipt has unsynchronized changes
  Future<bool> hasUnsynchronizedChanges(String receiptId) async {
    if (_goodReceiptsCollection == null ||
        _goodReceiptItemsCollection == null) {
      await initialize();
    }

    try {
      // Check if the receipt itself is unsynchronized
      final receiptDoc = await _goodReceiptsCollection!.document(receiptId);
      if (receiptDoc == null) {
        return false;
      }

      final receipt = receiptDoc.toPlainMap();
      if (receipt['syncedWithServer'] != true) {
        return true;
      }

      // Check if any items are unsynchronized
      final items = await getGoodReceiptItems(receiptId);
      for (final item in items) {
        if (item['syncedWithServer'] != true) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for unsynchronized changes: $e');
      return false;
    }
  }
}
