import 'package:flutter/material.dart';
import '../services/good_receipt_service.dart';
import '../models/good_receipt.dart';
import 'dart:math' as math;
import '../services/device_id_service.dart';
import 'goods_receipt_scan_item_page.dart';

class GoodsReceiptDetailsPage extends StatefulWidget {
  static const routeName = '/goods-receipt-details';
  final String receiptId;

  const GoodsReceiptDetailsPage({super.key, required this.receiptId});

  @override
  State<GoodsReceiptDetailsPage> createState() =>
      _GoodsReceiptDetailsPageState();
}

class _GoodsReceiptDetailsPageState extends State<GoodsReceiptDetailsPage> {
  final GoodReceiptService _goodReceiptService = GoodReceiptService();
  bool _isLoading = true;
  GoodReceipt? _receipt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGoodReceipt();
  }

  Future<void> _fetchGoodReceipt() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use a filter to get a specific good receipt by ID
      final receiptsData = await _goodReceiptService.getGoodReceipts(
        filter: {'id': widget.receiptId},
      );

      if (receiptsData.isEmpty) {
        setState(() {
          _errorMessage = 'Good receipt not found';
          _isLoading = false;
        });
        return;
      }

      final receipt = GoodReceipt.fromJson(receiptsData.first);

      setState(() {
        _receipt = receipt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch good receipt: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateGoodReceiptStatus(int newStatus) async {
    if (_receipt == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await _goodReceiptService.updateGoodReceipt(
        id: _receipt!.id,
        status: newStatus,
      );

      await _fetchGoodReceipt();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _deleteGoodReceiptItem(String itemId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _goodReceiptService.deleteGoodReceiptItem(itemId);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        }
        await _fetchGoodReceipt(); // This will reset _isLoading to false when complete
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _navigateToScanItemPage() async {
    if (_receipt == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GoodsReceiptScanItemPage(
              goodReceiptId: _receipt!.id,
              onItemAdded: (Map<String, dynamic> item) {
                // This callback will be called when an item is added in the scan page
                // Refresh the receipt details to show the new item
                _fetchGoodReceipt();
              },
            ),
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    if (_receipt == null) return;

    final itemCodeController = TextEditingController();
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    final uomController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: itemCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Item Code',
                    hintText: 'Enter item code',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter item name',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter quantity',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText: 'Enter price',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: uomController,
                  decoration: const InputDecoration(
                    labelText: 'UOM',
                    hintText: 'Enter unit of measure',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (itemCodeController.text.isEmpty ||
                    nameController.text.isEmpty ||
                    qtyController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    uomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                try {
                  double qty = double.parse(qtyController.text);
                  double price = double.parse(priceController.text);

                  await _goodReceiptService.createGoodReceiptItem(
                    goodReceiptId: _receipt!.id,
                    itemCode: itemCodeController.text.trim(),
                    name: nameController.text.trim(),
                    qty: qty,
                    price: price,
                    uom: uomController.text.trim(),
                    deviceId: await DeviceIdService().getDeviceId(),
                  );

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item added successfully')),
                    );
                    setState(() {
                      _isLoading = true;
                    });
                    await _fetchGoodReceipt();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    setState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding item: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_receipt?.name ?? 'Good Receipt Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _fetchGoodReceipt,
          // ),
        ],
      ),
      floatingActionButton:
          _receipt != null
              ? FloatingActionButton(
                onPressed: _navigateToScanItemPage,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              )
              : null,
      body:
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
                      onPressed: _fetchGoodReceipt,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _receipt == null
              ? const Center(child: Text('No receipt data available'))
              : Column(
                children: [
                  // Receipt Summary Card
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
                                'Supplier:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_receipt!.supplierCode),
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
                              Text(
                                _receipt!.createdAt.substring(
                                  0,
                                  math.min(10, _receipt!.createdAt.length),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Warehouse:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(_receipt!.whs),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Status:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              DropdownButton<int>(
                                value: _receipt!.status,
                                items: const [
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('Received'),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text('Verified'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null &&
                                      value != _receipt!.status) {
                                    _updateGoodReceiptStatus(value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Items List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Received Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(
                            _receipt!.statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Color(_receipt!.statusColor),
                        ),
                      ],
                    ),
                  ),
                  // Items List
                  Expanded(
                    child:
                        _receipt!.items.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No items found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed:
                                            () => _showAddItemDialog(context),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Item Manually'),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton.icon(
                                        onPressed:
                                            () => _navigateToScanItemPage(),
                                        icon: const Icon(Icons.qr_code_scanner),
                                        label: const Text('Scan Item'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _receipt!.items.length,
                              itemBuilder: (context, index) {
                                final item = _receipt!.items[index];
                                return Card(
                                  child: Dismissible(
                                    key: Key(item.id),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: 16.0,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Confirm Delete'),
                                            content: Text(
                                              'Are you sure you want to delete ${item.name}?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteGoodReceiptItem(item.id);
                                    },
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text('SKU: ${item.itemCode}'),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Quantity: ${item.qty}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          'Price: \$${item.price.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      'UOM: ${item.uom}',
                                                      style: TextStyle(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showAddItemDialog(context);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Return true to indicate changes were made
                              Navigator.pop(context, true);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  int min(int a, int b) {
    return math.min(a, b);
  }
}
