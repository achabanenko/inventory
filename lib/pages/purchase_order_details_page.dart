import 'package:flutter/material.dart';
import 'purchase_order_scan_item_page.dart';
import '../services/graphql_service.dart';

class PurchaseOrderDetailsPage extends StatefulWidget {
  final String orderNumber;
  final Map<String, dynamic> order;

  const PurchaseOrderDetailsPage({
    super.key,
    required this.orderNumber,
    required this.order,
  });

  @override
  State<PurchaseOrderDetailsPage> createState() =>
      _PurchaseOrderDetailsPageState();
}

class _PurchaseOrderDetailsPageState extends State<PurchaseOrderDetailsPage> {
  late List<Map<String, dynamic>> orderItems = [];
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize order items from the order document
    _initializeOrderItems();
  }

  Future<void> _initializeOrderItems() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final filter = {'id': widget.order['id'] ?? ''};
      final orders = await _purchaseOrderService.getPurchaseOrders(
        filter: filter,
        // Use noCache to ensure we get the latest data
      );

      if (orders.isEmpty) {
        debugPrint('Purchase order not found: ${widget.orderNumber}');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final pulledOrder = orders.first;

      setState(() {
        orderItems = List<Map<String, dynamic>>.from(
          pulledOrder['items'] ?? [],
        );
        // Update the local order object with the latest data
        widget.order['items'] = orderItems;
        _isSaving = false;
        debugPrint(
          'Loaded ${orderItems.length} items from order: ${widget.orderNumber}',
        );
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      debugPrint('Error loading purchase order: $e');
    }
  }

  void _addItemToOrder(Map<String, dynamic> item) async {
    debugPrint('Adding item to order: $item');
    debugPrint('Current orderItems before adding: $orderItems');

    setState(() {
      _isSaving = true;
      // Check if the item already exists in the order
      final existingItemIndex = orderItems.indexWhere(
        (element) => element['itemCode'] == item['itemCode'],
      );
      debugPrint('Existing item index: $existingItemIndex');

      if (existingItemIndex >= 0) {
        // If item exists, add the new quantity to the existing quantity
        final existingQuantity = orderItems[existingItemIndex]['qty'] ?? 0;
        final newQuantity = item['qty'] ?? 1;
        orderItems[existingItemIndex]['qty'] = existingQuantity + newQuantity;
        debugPrint(
          'Updated quantity for existing item: ${orderItems[existingItemIndex]}',
        );
      } else {
        // Otherwise add new item
        orderItems.add(item);
        debugPrint('Added new item to orderItems');
      }

      // Update the order with the new items list
      widget.order['items'] = orderItems;
      debugPrint('Updated order[items]: ${widget.order["items"]}');
      debugPrint('Current orderItems after adding: $orderItems');
    });

    // No need to update the purchase order here as the item is already created via GraphQL
    // in the scan page and will be retrieved when we refresh the items list
    
    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added to purchase order'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openScanItemPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => PurchaseOrderScanItemPage(
              purchaseOrderId: widget.order['id'] ?? '',
              onItemAdded: _addItemToOrder,
            ),
      ),
    ).then((_) {
      // Refresh items when returning from scan page
      _initializeOrderItems();
    });
  }

  void _submitToApi() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Submit to API'),
            content: Text(
              'Are you sure you want to submit Purchase Order ${widget.orderNumber} with ${orderItems.length} items to the API?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Update the purchase order status to submitted (status 1)
      await _purchaseOrderService.updatePurchaseOrder(
        id: widget.order['id'] ?? '',
        status: 1, // Submitted status
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Purchase order ${widget.orderNumber} submitted successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Go back to the purchase orders list
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting purchase order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug information about order items
    debugPrint(
      'Building PurchaseOrderDetailsPage with ${orderItems.length} items',
    );
    if (orderItems.isNotEmpty) {
      debugPrint('First item sample: ${orderItems.first}');
    }

    final String documentHeaderText =
        widget.order['name'] ?? 'Purchase Order Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(documentHeaderText),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Order Summary Card
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Items:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${orderItems.length} items'),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Supplier:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(widget.order['supplierCode'] ?? 'Unknown Supplier'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Date:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(DateTime.now().toString().substring(0, 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Items List Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Order Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orderItems.length,
              itemBuilder: (context, index) {
                final item = orderItems[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Product Image Placeholder
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Product Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['itemCode'] ?? 'Unknown Product',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'name: ${item['productName'] ?? item['name'] ?? 'N/A'}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${item['quantity'] ?? item['qty'] ?? 0}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Spacer at the bottom
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Submit to API button
          FloatingActionButton.extended(
            onPressed: _submitToApi,
            backgroundColor: Colors.green,
            label: const Text('Submit to API'),
            icon: const Icon(Icons.cloud_upload, color: Colors.white),
            heroTag: 'submit_button',
          ),
          const SizedBox(height: 16),
          // Scan items button
          FloatingActionButton(
            onPressed: _openScanItemPage,
            backgroundColor: Theme.of(context).colorScheme.primary,
            heroTag: 'scan_button',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
