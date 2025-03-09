import 'package:flutter/material.dart';
import 'graphql_service.dart';
import 'package:graphql/client.dart';

class WarehouseService {
  final GraphQLService _graphQLService = GraphQLService();

  // Query to fetch all warehouses
  Future<List<Map<String, dynamic>>> getWarehouses({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetWarehouses($filter: WarehouseFilter) {
        warehouses(filter: $filter) {
          id
          code
          name
          createdAt
          updatedAt
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

      final List<dynamic> data = result.data?['warehouses'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching warehouses: $e');
      rethrow;
    }
  }
}

class SupplierService {
  final GraphQLService _graphQLService = GraphQLService();

  // Query to fetch all suppliers
  Future<List<Map<String, dynamic>>> getSuppliers({
    Map<String, dynamic>? filter,
  }) async {
    const String query = r'''
      query GetSuppliers($filter: SupplierFilter) {
        suppliers(filter: $filter) {
          id
          code
          name
          createdAt
          updatedAt
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

      final List<dynamic> data = result.data?['suppliers'] ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
      rethrow;
    }
  }
}
