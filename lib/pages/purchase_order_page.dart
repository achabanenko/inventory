import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/graphql_service.dart';
import 'purchase_order_details_page.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final DatabaseService _databaseService = DatabaseService();
  Future<List<Map<String, dynamic>>> _purchaseOrders = Future.value(
    <Map<String, dynamic>>[],
  );
  bool _isLoading = false;
  bool _isOfflineMode = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _initializeDatabase() async {
    try {
      await _databaseService.initialize();
      _loadPurchaseOrders();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize database: ${e.toString()}';
      });
    }
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineMode = false;
    });

    try {
      // Initialize GraphQL service before using it
      final graphQLService = GraphQLService();
      await graphQLService.initialize();

      // Use GraphQL service to fetch purchase orders
      final orders = await _purchaseOrderService.getPurchaseOrders();
      _purchaseOrders = Future.value(orders);
    } catch (e) {
      // If GraphQL query fails
      setState(() {
        _errorMessage = 'Failed to load purchase orders: ${e.toString()}';
        _isOfflineMode = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to sync all purchase orders with the remote server
  Future<void> _syncAllPurchaseOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize GraphQL service before using it
      final graphQLService = GraphQLService();
      await graphQLService.initialize();

      // Get all orders from the server
      final serverOrders = await _purchaseOrderService.getPurchaseOrders();

      if (serverOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No purchase orders found on server'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      int syncedCount = 0;
      List<String> failedOrders = [];

      // Update each order
      for (final serverOrder in serverOrders) {
        final String orderId = serverOrder['id'] ?? '';
        if (orderId.isEmpty) continue;

        try {
          await _purchaseOrderService.updatePurchaseOrder(
            id: orderId,
            name: serverOrder['name'],
            status: serverOrder['status'],
            supplierCode: serverOrder['supplierCode'],
            whs: serverOrder['whs'],
            // delDate: serverOrder['delDate'],
          );
          syncedCount++;
        } catch (e) {
          failedOrders.add(serverOrder['name'] ?? 'Unknown');
        }
      }

      // Show results
      if (failedOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $syncedCount purchase orders'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced $syncedCount orders. Failed to sync: ${failedOrders.join(', ')}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Refresh the list
      _loadPurchaseOrders();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync orders: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to delete a purchase order
  Future<void> _deletePurchaseOrder(Map<String, dynamic> order) async {
    final String orderId = order['id'] ?? '';
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Invalid order ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Purchase Order'),
            content: Text(
              'Are you sure you want to delete purchase order ${order['name']}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize GraphQL service before using it
      final graphQLService = GraphQLService();
      await graphQLService.initialize();

      // Delete the purchase order using GraphQL
      final success = await _purchaseOrderService.deletePurchaseOrder(orderId);

      if (!success) {
        throw Exception('Server returned failure status');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase order deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list
      _loadPurchaseOrders();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Filter orders based on search query
  List<Map<String, dynamic>> _getFilteredOrders(List<dynamic> orders) {
    if (_searchQuery.isEmpty) {
      return List<Map<String, dynamic>>.from(orders);
    }

    final query = _searchQuery.toLowerCase();
    return List<Map<String, dynamic>>.from(
      orders.where((order) {
        final orderNumber = order['name']?.toString().toLowerCase() ?? '';
        return orderNumber.contains(query);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text('Purchase Orders', overflow: TextOverflow.ellipsis),
            ),
            if (_isOfflineMode)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncAllPurchaseOrders,
            tooltip: 'Sync all orders',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchaseOrders,
            tooltip: 'Refresh from server',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by order number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // Main content
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPurchaseOrders,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : FutureBuilder(
                      future: _purchaseOrders,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('No purchase orders found'),
                          );
                        }

                        final orders = snapshot.data!;
                        final filteredOrders = _getFilteredOrders(orders);

                        if (filteredOrders.isEmpty && _searchQuery.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No purchase orders matching "$_searchQuery"',
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            // Adjust these fields based on your actual API response structure
                            final orderNumber =
                                order['name']?.toString() ?? 'N/A';

                            // Format the date if it exists
                            String orderDate = 'N/A';
                            if (order['createdAt'] != null) {
                              try {
                                final dateTime = DateTime.parse(
                                  order['createdAt'].toString(),
                                );
                                orderDate =
                                    '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
                              } catch (e) {
                                orderDate = order['createdAt'].toString();
                              }
                            }

                            // Get item count
                            final items =
                                order['items'] as List<dynamic>? ?? [];
                            final itemCount = items.length;

                            final status =
                                order['status']?.toString() ?? 'Unknown';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: const Text('PO'),
                                    ),
                                    title: Text('Order #$orderNumber'),
                                    subtitle: Text(
                                      '$orderDate | Items: $itemCount',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor:
                                          status.toLowerCase() == 'completed'
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  PurchaseOrderDetailsPage(
                                                    orderNumber: orderNumber,
                                                    order: order,
                                                  ),
                                        ),
                                      );
                                    },
                                  ),
                                  ButtonBar(
                                    alignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.visibility,
                                          size: 18,
                                        ),
                                        label: const Text('View'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      PurchaseOrderDetailsPage(
                                                        orderNumber:
                                                            orderNumber,
                                                        order: order,
                                                      ),
                                            ),
                                          );
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed:
                                            () => _deletePurchaseOrder(order),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new purchase order
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
