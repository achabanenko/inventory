import 'package:graphql/client.dart';
import 'api_settings_service.dart';
import 'package:flutter/material.dart';

class GraphQLService {
  static final GraphQLService _instance = GraphQLService._internal();
  late GraphQLClient _client;
  final ApiSettingsService _apiSettingsService = ApiSettingsService();

  factory GraphQLService() {
    return _instance;
  }

  GraphQLService._internal();

  Future<void> initialize() async {
    final apiUrl = await _apiSettingsService.getApiUrl();
    final apiKey = await _apiSettingsService.getApiKey();

    final httpLink = HttpLink('$apiUrl/api/graphql');

    final authLink = AuthLink(
      headerKey: 'x-api-key',
      getToken: () async => apiKey,
    );

    final link = authLink.concat(httpLink);

    _client = GraphQLClient(
      link: link,
      cache: GraphQLCache(), // Still need the cache property
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.noCache, // Don't use cache for queries
        ),
        mutate: Policies(
          fetch: FetchPolicy.noCache, // Don't use cache for mutations
        ),
      ),
    );
  }

  // Flag to track initialization status
  bool _isInitializing = false;
  bool _isInitialized = false;
  
  // Getter for initialization status
  bool get isInitialized => _isInitialized;
  
  // Async method to get a properly initialized client
  Future<GraphQLClient> getInitializedClient() async {
    if (_isInitialized) {
      return _client;
    }
    
    if (!_isInitializing) {
      _isInitializing = true;
      try {
        await initialize();
        _isInitialized = true;
        _isInitializing = false;
        debugPrint('GraphQL client initialized successfully');
      } catch (error) {
        _isInitializing = false;
        debugPrint('Error initializing GraphQL client: $error');
        rethrow;
      }
    } else {
      // Wait for initialization to complete if already in progress
      int attempts = 0;
      while (!_isInitialized && attempts < 5) {
        debugPrint('Waiting for GraphQL client initialization... (attempt ${attempts + 1})');
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
      }
      
      if (!_isInitialized) {
        throw Exception('GraphQL client initialization timeout');
      }
    }
    
    return _client;
  }
  
  // Synchronous getter for client - use with caution
  GraphQLClient get client {
    if (_isInitialized) {
      return _client;
    }
    
    debugPrint('WARNING: Accessing GraphQL client before initialization');
    // Start initialization if not already in progress
    if (!_isInitializing) {
      _isInitializing = true;
      initialize().then((_) {
        _isInitialized = true;
        _isInitializing = false;
        debugPrint('GraphQL client initialized successfully');
      }).catchError((error) {
        _isInitializing = false;
        debugPrint('Error initializing GraphQL client: $error');
      });
    }
    
    // Return a temporary client with default settings
    final apiUrl = 'http://localhost:4000'; // Default URL
    final httpLink = HttpLink('$apiUrl/api/graphql');
    return GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(),
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.noCache,
        ),
        mutate: Policies(
          fetch: FetchPolicy.noCache,
        ),
      ),
    );
  }

  // Method to refresh the client with updated settings
  Future<void> refreshClient() async {
    await initialize();
  }
}

class GoodReceiptService {
  final GraphQLService _graphQLService = GraphQLService();

  // Query to fetch all good receipts with items (for details view)
  Future<List<Map<String, dynamic>>> getGoodReceipts({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetGoodReceipts($filter: GoodReceiptFilter) {
        goodReceipts(filter: $filter) {
          id
          name
          status
          supplierCode
          whs
          delDate
          createdAt
          updatedAt
          items {
            id
            goodReceiptId
            itemCode
            name
            qty
            price
            uom
            deviceId
          }
        }
      }
    ''';

    try {
      // Use the async client initialization
      final client = await _graphQLService.getInitializedClient();
      
      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {
            'filter': {'status': 0, ...filter ?? {}},
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final List<dynamic> data = result.data?['goodReceipts'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching good receipts with items: $e');
      rethrow;
    }
  }
  
  // Query to fetch only good receipt headers (for list view)
  Future<List<Map<String, dynamic>>> getGoodReceiptHeaders({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetGoodReceiptHeaders($filter: GoodReceiptFilter) {
        goodReceipts(filter: $filter) {
          id
          name
          status
          supplierCode
          whs
          delDate
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.query(
        QueryOptions(
          document: gql(query),
          variables: {
            'filter': {'status': 0, ...filter ?? {}},
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final List<dynamic> data = result.data?['goodReceipts'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching good receipt headers: $e');
      rethrow;
    }
  }

  // Mutation to create a new good receipt
  Future<Map<String, dynamic>> createGoodReceipt({
    required String name,
    required int status,
    required String supplierCode,
    required String whs,
    String? delDate,
  }) async {
    const String mutation = r'''
      mutation CreateGoodReceipt(
        $name: String!,
        $status: Int!,
        $supplierCode: String!,
        $whs: String!,
        $delDate: String
      ) {
        createGoodReceipt(
          name: $name,
          status: $status,
          supplierCode: $supplierCode,
          whs: $whs,
          delDate: $delDate
        ) {
          id
          name
          status
          supplierCode
          whs
          delDate
          createdAt
          updatedAt
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'name': name,
            'status': status,
            'supplierCode': supplierCode,
            'whs': whs,
            'delDate': delDate,
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createGoodReceipt'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating good receipt: $e');
      rethrow;
    }
  }

  // Mutation to update an existing good receipt
  Future<Map<String, dynamic>> updateGoodReceipt({
    required String id,
    String? name,
    int? status,
    String? supplierCode,
    String? whs,
    String? delDate,
  }) async {
    const String mutation = r'''
      mutation UpdateGoodReceipt($input: UpdateGoodReceiptInput!) {
        updateGoodReceipt(input: $input) {
          id
          name
          status
          supplierCode
          whs
          delDate
          createdAt
          updatedAt
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (supplierCode != null) 'supplierCode': supplierCode,
      if (whs != null) 'whs': whs,
      if (delDate != null) 'delDate': delDate,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updateGoodReceipt'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating good receipt: $e');
      rethrow;
    }
  }

  // Mutation to delete a good receipt
  Future<bool> deleteGoodReceipt(String id) async {
    const String mutation = r'''
      mutation DeleteGoodReceipt($id: ID!) {
        deleteGoodReceipt(id: $id) {
          success
          message
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deleteGoodReceipt']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting good receipt: $e');
      rethrow;
    }
  }

  // Mutation to create a good receipt item
  Future<Map<String, dynamic>> createGoodReceiptItem({
    required String goodReceiptId,
    required String itemCode,
    required String name,
    required double qty,
    required double price,
    required String uom,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation CreateGoodReceiptItem($input: CreateGoodReceiptItemInput!) {
        createGoodReceiptItem(input: $input) {
          id
          goodReceiptId
          itemCode
          name
          qty
          price
          uom
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'goodReceiptId': goodReceiptId,
      'itemCode': itemCode,
      'name': name,
      'qty': qty,
      'price': price,
      'uom': uom,
      'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createGoodReceiptItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating good receipt item: $e');
      rethrow;
    }
  }

  // Mutation to update a good receipt item
  Future<Map<String, dynamic>> updateGoodReceiptItem({
    required String id,
    String? itemCode,
    String? name,
    double? qty,
    double? price,
    String? uom,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation UpdateGoodReceiptItem($input: UpdateGoodReceiptItemInput!) {
        updateGoodReceiptItem(input: $input) {
          id
          goodReceiptId
          itemCode
          name
          qty
          price
          uom
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (itemCode != null) 'itemCode': itemCode,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (price != null) 'price': price,
      if (uom != null) 'uom': uom,
      if (deviceId != null) 'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updateGoodReceiptItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating good receipt item: $e');
      rethrow;
    }
  }

  // Mutation to delete a good receipt item
  Future<bool> deleteGoodReceiptItem(String id) async {
    const String mutation = r'''
      mutation DeleteGoodReceiptItem($id: ID!) {
        deleteGoodReceiptItem(id: $id) {
          success
          message
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deleteGoodReceiptItem']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting good receipt item: $e');
      rethrow;
    }
  }

  // Query to get all items for a specific good receipt
  Future<List<Map<String, dynamic>>> getGoodReceiptItems(
    String goodReceiptId,
  ) async {
    const String query = r'''
      query GetGoodReceiptItems($goodReceiptId: ID!) {
        goodReceiptItems(goodReceiptId: $goodReceiptId) {
          id
          goodReceiptId
          itemCode
          name
          qty
          price
          uom
          deviceId
        }
      }
    ''';

    try {
      debugPrint('Fetching items for receipt $goodReceiptId from server');
      final result = await _graphQLService.client.query(
        QueryOptions(
          document: gql(query),
          variables: {'goodReceiptId': goodReceiptId},
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final items = result.data?['goodReceiptItems'] as List<dynamic>?;
      if (items == null) {
        return [];
      }

      return items.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching good receipt items from server: $e');
      rethrow;
    }
  }
}

class PurchaseOrderService {
  final GraphQLService _graphQLService = GraphQLService();

  // Query to fetch all purchase orders
  Future<List<Map<String, dynamic>>> getPurchaseOrders({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetPurchaseOrders($filter: PurchaseOrderFilter) {
        purchaseOrders(filter: $filter) {
          id
          createdAt
          updatedAt
          name
          status
          supplierCode
          whs
          delDate
          items {
            id
            purchaseOrderId
            itemCode
            name
            qty
            deviceId
          }
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.query(
        QueryOptions(
          document: gql(query),
          variables: {'filter': filter ?? {}},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final List<dynamic> data = result.data?['purchaseOrders'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching purchase orders: $e');
      rethrow;
    }
  }

  // Mutation to create a new purchase order
  Future<Map<String, dynamic>> createPurchaseOrder({
    required String name,
    required int status,
    required String supplierCode,
    required String whs,
    String? delDate,
  }) async {
    const String mutation = r'''
      mutation CreatePurchaseOrder(
        $name: String!,
        $status: Int!,
        $supplierCode: String!,
        $whs: String!,
        $delDate: String
      ) {
        createPurchaseOrder(
          name: $name,
          status: $status,
          supplierCode: $supplierCode,
          whs: $whs,
          delDate: $delDate
        ) {
          id
          createdAt
          updatedAt
          name
          status
          supplierCode
          whs
          delDate
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {
            'name': name,
            'status': status,
            'supplierCode': supplierCode,
            'whs': whs,
            'delDate': delDate,
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createPurchaseOrder'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating purchase order: $e');
      rethrow;
    }
  }

  // Mutation to update an existing purchase order
  Future<Map<String, dynamic>> updatePurchaseOrder({
    required String id,
    String? name,
    int? status,
    String? supplierCode,
    String? whs,
    String? delDate,
  }) async {
    const String mutation = r'''
      mutation UpdatePurchaseOrder($input: UpdatePurchaseOrderInput!) {
        updatePurchaseOrder(input: $input) {
          id
          createdAt
          updatedAt
          name
          status
          supplierCode
          whs
          delDate
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (supplierCode != null) 'supplierCode': supplierCode,
      if (whs != null) 'whs': whs,
      if (delDate != null) 'delDate': delDate,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updatePurchaseOrder'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating purchase order: $e');
      rethrow;
    }
  }

  // Mutation to delete a purchase order
  Future<bool> deletePurchaseOrder(String id) async {
    const String mutation = r'''
      mutation DeletePurchaseOrder($id: ID!) {
        deletePurchaseOrder(id: $id) {
          success
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deletePurchaseOrder']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting purchase order: $e');
      rethrow;
    }
  }

  // Mutation to create a purchase order item
  Future<Map<String, dynamic>> createPurchaseOrderItem({
    required String purchaseOrderId,
    required String itemCode,
    required String name,
    required double qty,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation CreatePurchaseOrderItem($input: CreatePurchaseOrderItemInput!) {
        createPurchaseOrderItem(input: $input) {
          id
          purchaseOrderId
          itemCode
          name
          qty
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'purchaseOrderId': purchaseOrderId,
      'itemCode': itemCode,
      'name': name,
      'qty': qty,
      'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createPurchaseOrderItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating purchase order item: $e');
      rethrow;
    }
  }

  // Mutation to update a purchase order item
  Future<Map<String, dynamic>> updatePurchaseOrderItem({
    required String id,
    String? itemCode,
    String? name,
    double? qty,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation UpdatePurchaseOrderItem($input: UpdatePurchaseOrderItemInput!) {
        updatePurchaseOrderItem(input: $input) {
          id
          purchaseOrderId
          itemCode
          name
          qty
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (itemCode != null) 'itemCode': itemCode,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (deviceId != null) 'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updatePurchaseOrderItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating purchase order item: $e');
      rethrow;
    }
  }

  // Mutation to delete a purchase order item
  Future<bool> deletePurchaseOrderItem(String id) async {
    const String mutation = r'''
      mutation DeletePurchaseOrderItem($id: ID!) {
        deletePurchaseOrderItem(id: $id) {
          success
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deletePurchaseOrderItem']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting purchase order item: $e');
      rethrow;
    }
  }
}

class PrintLabelService {
  final GraphQLService _graphQLService = GraphQLService();

  // Query to fetch all print labels
  Future<List<Map<String, dynamic>>> getPrintLabels({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetPrintLabels($filter: PrintLabelFilter) {
        printLabels(filter: $filter) {
          id
          createdAt
          updatedAt
          name
          status
          whs
          items {
            id
            printLabelId
            itemCode
            name
            qty
            deviceId
          }
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.query(
        QueryOptions(
          document: gql(query),
          variables: {'filter': filter ?? {}},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final List<dynamic> data = result.data?['printLabels'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching print labels: $e');
      rethrow;
    }
  }

  // Mutation to create a new print label
  Future<Map<String, dynamic>> createPrintLabel({
    required String name,
    required int status,
    required String whs,
  }) async {
    const String mutation = r'''
      mutation CreatePrintLabel(
        $name: String!,
        $status: Int!,
        $whs: String!
      ) {
        createPrintLabel(
          name: $name,
          status: $status,
          whs: $whs
        ) {
          id
          createdAt
          updatedAt
          name
          status
          whs
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {'name': name, 'status': status, 'whs': whs},
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createPrintLabel'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating print label: $e');
      rethrow;
    }
  }

  // Mutation to update an existing print label
  Future<Map<String, dynamic>> updatePrintLabel({
    required String id,
    String? name,
    int? status,
    String? whs,
  }) async {
    const String mutation = r'''
      mutation UpdatePrintLabel($input: UpdatePrintLabelInput!) {
        updatePrintLabel(input: $input) {
          id
          createdAt
          updatedAt
          name
          status
          whs
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (whs != null) 'whs': whs,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updatePrintLabel'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating print label: $e');
      rethrow;
    }
  }

  // Mutation to delete a print label
  Future<bool> deletePrintLabel(String id) async {
    const String mutation = r'''
      mutation DeletePrintLabel($id: ID!) {
        deletePrintLabel(id: $id) {
          success
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deletePrintLabel']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting print label: $e');
      rethrow;
    }
  }

  // Mutation to create a print label item
  Future<Map<String, dynamic>> createPrintLabelItem({
    required String printLabelId,
    required String itemCode,
    required String name,
    required double qty,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation CreatePrintLabelItem($input: CreatePrintLabelItemInput!) {
        createPrintLabelItem(input: $input) {
          id
          printLabelId
          itemCode
          name
          qty
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'printLabelId': printLabelId,
      'itemCode': itemCode,
      'name': name,
      'qty': qty,
      'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['createPrintLabelItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error creating print label item: $e');
      rethrow;
    }
  }

  // Mutation to update a print label item
  Future<Map<String, dynamic>> updatePrintLabelItem({
    required String id,
    String? itemCode,
    String? name,
    double? qty,
    String? deviceId,
  }) async {
    const String mutation = r'''
      mutation UpdatePrintLabelItem($input: UpdatePrintLabelItemInput!) {
        updatePrintLabelItem(input: $input) {
          id
          printLabelId
          itemCode
          name
          qty
          deviceId
        }
      }
    ''';

    final Map<String, dynamic> input = {
      'id': id,
      if (itemCode != null) 'itemCode': itemCode,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (deviceId != null) 'deviceId': deviceId,
    };

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'input': input}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['updatePrintLabelItem'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error updating print label item: $e');
      rethrow;
    }
  }

  // Mutation to delete a print label item
  Future<bool> deletePrintLabelItem(String id) async {
    const String mutation = r'''
      mutation DeletePrintLabelItem($id: ID!) {
        deletePrintLabelItem(id: $id) {
          success
        }
      }
    ''';

    try {
      final result = await _graphQLService.client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': id}),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      return result.data?['deletePrintLabelItem']['success'] as bool;
    } catch (e) {
      debugPrint('Error deleting print label item: $e');
      rethrow;
    }
  }
}
