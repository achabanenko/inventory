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
  bool _isPushing = false;
  bool _hasPendingChanges = false;
  GoodReceipt? _receipt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGoodReceipt();
  }
  
  // This method is no longer used as we directly set _hasPendingChanges when we detect changes

  Future<void> _pushToServer() async {
    if (_receipt == null) return;
    
    try {
      setState(() {
        _isPushing = true;
      });
      
      // IMPORTANT: We'll keep track of the current UI state and maintain it
      // This ensures deleted items don't reappear
      final currentItems = List<GoodReceiptItem>.from(_receipt!.items);
      debugPrint('PUSH DEBUG: Current UI has ${currentItems.length} items before push');
      
      // Push to server
      final bool success = await _goodReceiptService.pushGoodReceiptToServer(_receipt!.id);
      
      // Mark the push as complete, but KEEP THE CURRENT UI STATE
      setState(() {
        _isPushing = false;
        _hasPendingChanges = false;
      });
      
      if (mounted) {
        String message = success 
          ? 'Successfully pushed to server'
          : 'Failed to push to server';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message))
        );
      }
      
    } catch (e) {
      setState(() {
        _isPushing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pushing to server: $e'))
        );
      }
    }
  }

  Future<void> _fetchGoodReceipt() async {
    try {
      debugPrint('Starting to fetch good receipt ${widget.receiptId}');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Save the current receipt items if we have any (to preserve local changes)
      List<GoodReceiptItem>? currentItems;
      if (_receipt != null && _receipt!.items.isNotEmpty) {
        currentItems = List.from(_receipt!.items);
        debugPrint('Saved ${currentItems.length} current items before refresh');
      }

      // Get the local items first to check for deleted items
      final localItems = await _goodReceiptService.getGoodReceiptItems(widget.receiptId);
      final Set<String> locallyDeletedItemIds = {};
      
      // Identify locally deleted items
      for (var item in localItems) {
        if (item['deleted'] == true && item['serverId'] != null) {
          locallyDeletedItemIds.add(item['serverId'] as String);
          debugPrint('FETCH DEBUG: Found locally deleted item with server ID: ${item['serverId']}');
        }
      }
      
      // Try to fetch from server first
      debugPrint('Fetching receipt from server first');
      Map<String, dynamic>? serverReceiptData;
      try {
        serverReceiptData = await _goodReceiptService.fetchSingleGoodReceiptWithItems(
          widget.receiptId,
        );
      } catch (serverError) {
        debugPrint('Error fetching from server: $serverError');
        // Continue to local fetch
      }
      
      if (serverReceiptData != null) {
        // Use the server data as the base
        var receipt = GoodReceipt.fromJson(serverReceiptData);
        debugPrint('Server receipt found with ${receipt.items.length} items');
        
        // Filter out items that have been deleted locally
        List<GoodReceiptItem> filteredServerItems = receipt.items.where((item) {
          // Check if this server item has been deleted locally
          bool isDeleted = locallyDeletedItemIds.contains(item.id);
          if (isDeleted) {
            debugPrint('FETCH DEBUG: Filtering out server item ${item.id} - ${item.itemCode} because it was deleted locally');
          }
          return !isDeleted;
        }).toList();
        
        debugPrint('After filtering deleted items, server has ${filteredServerItems.length} items');
        
        // Create a new receipt with the filtered items
        receipt = GoodReceipt(
          id: receipt.id,
          name: receipt.name,
          status: receipt.status,
          supplierCode: receipt.supplierCode,
          whs: receipt.whs,
          delDate: receipt.delDate,
          createdAt: receipt.createdAt,
          updatedAt: receipt.updatedAt,
          items: filteredServerItems,
        );
        
        // Log all remaining items from the server
        for (int i = 0; i < receipt.items.length; i++) {
          debugPrint('Filtered server item $i: ${receipt.items[i].itemCode} - ${receipt.items[i].name}');
        }

        // Check if we need to merge with local items
        if (currentItems != null) {
          // Create a new list for all items (we can't modify receipt.items directly as it's final)
          List<GoodReceiptItem> mergedItems = [];
          
          // First, add all non-deleted items from the server
          mergedItems.addAll(receipt.items.where((item) => item.deleted != true));
          
          // Find items that exist locally but not on the server
          final Set<String> serverItemIds = receipt.items.map((item) => item.id).toSet();
          
          // Get local-only items that are not marked as deleted
          final List<GoodReceiptItem> localOnlyItems = currentItems
              .where((item) => !serverItemIds.contains(item.id) && item.deleted != true)
              .toList();
          
          if (localOnlyItems.isNotEmpty) {
            debugPrint('Found ${localOnlyItems.length} items that exist locally but not on server');
            // Add the local-only items to our merged list
            mergedItems.addAll(localOnlyItems);
            setState(() {
              _hasPendingChanges = true; // Mark that we have pending changes to push
            });
          }
          
          // Create a new receipt with the merged items list
          receipt = GoodReceipt(
            id: receipt.id,
            name: receipt.name,
            status: receipt.status,
            supplierCode: receipt.supplierCode,
            whs: receipt.whs,
            delDate: receipt.delDate,
            createdAt: receipt.createdAt,
            updatedAt: receipt.updatedAt,
            items: mergedItems,
          );
        }
        
        setState(() {
          _receipt = receipt;
          _isLoading = false;
        });
      } else {
        // If server fetch fails, fall back to local database
        debugPrint('No server receipt found, trying local database');
        final localReceipt = await _goodReceiptService.getGoodReceipt(widget.receiptId);
        
        if (localReceipt == null) {
          debugPrint('Receipt not found locally either');
          setState(() {
            _errorMessage = 'Good receipt not found';
            _isLoading = false;
          });
          return;
        }
        
        // Get the local data
        final rawReceipt = GoodReceipt.fromJson(localReceipt);
        debugPrint('Local receipt found with ${rawReceipt.items.length} items');
        
        // Filter out any items that are marked as deleted
        final nonDeletedItems = rawReceipt.items.where((item) => item.deleted != true).toList();
        debugPrint('After filtering deleted items, local receipt has ${nonDeletedItems.length} items');
        
        // Create a new receipt with only non-deleted items
        final receipt = GoodReceipt(
          id: rawReceipt.id,
          name: rawReceipt.name,
          status: rawReceipt.status,
          supplierCode: rawReceipt.supplierCode,
          whs: rawReceipt.whs,
          delDate: rawReceipt.delDate,
          createdAt: rawReceipt.createdAt,
          updatedAt: rawReceipt.updatedAt,
          items: nonDeletedItems,
        );
        
        setState(() {
          _receipt = receipt;
          _isLoading = false;
          _hasPendingChanges = true; // Mark as having pending changes since server doesn't have this data
        });
      }
      
      // Force a rebuild of the UI
      if (mounted) {
        setState(() {});
      }
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

      // First remove the item from the local UI immediately
      if (_receipt != null) {
        setState(() {
          // Find the item index
          final itemIndex = _receipt!.items.indexWhere((item) => item.id == itemId);
          if (itemIndex != -1) {
            // Store the deleted item temporarily in case we need to restore it
            final deletedItem = _receipt!.items[itemIndex];
            debugPrint('Removing item ${deletedItem.itemCode} from UI');
            
            // Create a new list without the deleted item (since we can't modify the final list)
            final newItems = List<GoodReceiptItem>.from(_receipt!.items);
            newItems.removeAt(itemIndex);
            
            // Create a new receipt with the updated items list
            _receipt = GoodReceipt(
              id: _receipt!.id,
              name: _receipt!.name,
              status: _receipt!.status,
              supplierCode: _receipt!.supplierCode,
              whs: _receipt!.whs,
              delDate: _receipt!.delDate,
              createdAt: _receipt!.createdAt,
              updatedAt: _receipt!.updatedAt,
              items: newItems,
            );
            
            // Mark that we have pending changes
            _hasPendingChanges = true;
          }
        });
      }

      // Then delete from the database
      final success = await _goodReceiptService.deleteGoodReceiptItem(itemId);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        }
        
        // No need to fetch the receipt again as we've already updated the UI
        setState(() {
          _isLoading = false;
        });
      } else {
        // If the database delete failed, we should refresh to get the correct state
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
        // Refresh to get the correct state
        await _fetchGoodReceipt();
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
      // Refresh to get the correct state in case of error
      await _fetchGoodReceipt();
    }
  }

  Future<void> _navigateToScanItemPage() async {
    if (_receipt == null) return;

    // Store the current items count for debugging
    final int initialItemCount = _receipt!.items.length;
    debugPrint('Before scanning: Receipt has $initialItemCount items');

    // Track newly added items
    final List<GoodReceiptItem> newlyAddedItems = [];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoodsReceiptScanItemPage(
          goodReceiptId: _receipt!.id,
          onItemAdded: (Map<String, dynamic> item) {
            debugPrint('Item added callback received: ${item.toString()}');
            try {
              // Convert the item to a GoodReceiptItem and add it to the current receipt
              final newItem = GoodReceiptItem.fromJson(item);
              
              // Keep track of newly added items
              newlyAddedItems.add(newItem);
              
              // Update the UI immediately with the new item
              setState(() {
                // Add the new item to the existing receipt
                _receipt!.items.add(newItem);
                _hasPendingChanges = true;
              });
              
              debugPrint('Item added to UI: ${newItem.itemCode}, total items now: ${_receipt!.items.length}');
            } catch (e) {
              debugPrint('Error adding item to UI: $e');
              setState(() {
                _hasPendingChanges = true;
              });
            }
          },
        ),
      ),
    );
    
    // Log the current items count after returning from scan page
    debugPrint('After scanning: Receipt has ${_receipt!.items.length} items (before refresh)');
    
    if (newlyAddedItems.isEmpty) {
      debugPrint('No new items were added during scanning');
      return; // No need to refresh if nothing was added
    }
    
    // After returning from the scan page, refresh the receipt to ensure all data is in sync
    await _fetchGoodReceipt();
    
    // Log the final items count after refresh
    debugPrint('After refresh: Receipt has ${_receipt!.items.length} items');
    
    // Check if any newly scanned items are missing after refresh
    if (_receipt != null) {
      final Set<String> currentItemIds = _receipt!.items.map((item) => item.id).toSet();
      
      // Check for items that were added during scanning but are missing after refresh
      bool anyItemsMissing = false;
      for (final newItem in newlyAddedItems) {
        if (!currentItemIds.contains(newItem.id)) {
          debugPrint('Newly added item ${newItem.id} (${newItem.itemCode}) is missing after refresh');
          // Re-add the missing item
          _receipt!.items.add(newItem);
          anyItemsMissing = true;
        }
      }
      
      if (anyItemsMissing) {
        debugPrint('Re-added missing items to the receipt');
        setState(() {
          _hasPendingChanges = true;
        });
      }
    }
    
    // Force a rebuild of the UI
    setState(() {});
    
    // Debug log all items in the receipt
    for (int i = 0; i < _receipt!.items.length; i++) {
      debugPrint('Item $i: ${_receipt!.items[i].itemCode} - ${_receipt!.items[i].name}');
    }
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

                  // Create the item in the database
                  final addedItem = await _goodReceiptService.createGoodReceiptItem(
                    goodReceiptId: _receipt!.id,
                    itemCode: itemCodeController.text.trim(),
                    name: nameController.text.trim(),
                    qty: qty,
                    price: price,
                    uom: uomController.text.trim(),
                    deviceId: await DeviceIdService().getDeviceId(),
                  );

                  if (mounted) {
                    // Close the dialog
                    Navigator.of(context).pop();
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item added successfully')),
                    );
                    
                    debugPrint('Manual item added: ${addedItem.toString()}');
                    try {
                      // Convert the item to a GoodReceiptItem and add it to the current receipt
                      final newItem = GoodReceiptItem.fromJson(addedItem);
                      
                      // Update the UI immediately with the new item
                      setState(() {
                        // Add the new item to the existing receipt
                        _receipt!.items.add(newItem);
                        _hasPendingChanges = true;
                      });
                      
                      debugPrint('Manual item added to UI: ${newItem.itemCode}');
                    } catch (e) {
                      debugPrint('Error adding manual item to UI: $e');
                      // If there's an error in the immediate update, we'll rely on the full refresh
                      await _fetchGoodReceipt();
                    }
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
                            ? const Center(
                                child: Text(
                                  'No items found',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _receipt!.items.length,
                              itemBuilder: (context, index) {
                                debugPrint('Building item at index $index: ${_receipt!.items[index].itemCode}');
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
                    child: Column(
                      children: [
                        // Push to Server button - only visible when changes exist
                        if (_hasPendingChanges)
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isPushing ? null : _pushToServer,
                                icon: _isPushing 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload),
                                label: Text(_isPushing ? 'Pushing...' : 'Push to Server'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        // Add Item button (full width)
                        ElevatedButton.icon(
                          onPressed: () => _showAddItemDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            minimumSize: const Size(double.infinity, 50),
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
