import 'package:flutter/material.dart';
import 'goods_receipt_details_page.dart';
import '../services/good_receipt_service.dart';
import '../models/good_receipt.dart';

class GoodsReceiptPage extends StatefulWidget {
  const GoodsReceiptPage({super.key});

  @override
  State<GoodsReceiptPage> createState() => _GoodsReceiptPageState();
}

class _GoodsReceiptPageState extends State<GoodsReceiptPage> {
  final GoodReceiptService _goodReceiptService = GoodReceiptService();
  bool _isLoading = true;
  List<GoodReceipt> _goodReceipts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Initialize the local database first
      await _goodReceiptService.initialize();
      
      // Then try to fetch data
      await _fetchGoodReceipts();
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGoodReceipts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Try to fetch from server with retry logic
      List<Map<String, dynamic>> serverReceipts = [];
      bool fetchSuccess = false;
      String? lastError;
      
      // Try up to 3 times with increasing delays
      for (int attempt = 1; attempt <= 3 && !fetchSuccess; attempt++) {
        try {
          debugPrint('Fetching goods receipts from server (attempt $attempt)');
          // Only fetch headers from server for efficiency (no items needed for list view)
          serverReceipts = await _goodReceiptService.fetchServerGoodReceipts(fetchItems: false);
          fetchSuccess = true;
          debugPrint('Successfully fetched ${serverReceipts.length} receipts from server');
        } catch (e) {
          lastError = e.toString();
          debugPrint('Server fetch attempt $attempt failed: $e');
          
          if (attempt < 3) {
            // Wait before retrying (increasing delay)
            final delay = Duration(milliseconds: 500 * attempt);
            debugPrint('Retrying in ${delay.inMilliseconds}ms...');
            await Future.delayed(delay);
          }
        }
      }
      
      if (fetchSuccess) {
        // Convert to GoodReceipt objects
        final receipts = serverReceipts.map((data) => GoodReceipt.fromJson(data)).toList();
        
        setState(() {
          _goodReceipts = receipts;
          _isLoading = false;
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goods receipts loaded from server'))
          );
        }
      } else {
        // If all server attempts failed, try to load from local database
        debugPrint('All server attempts failed, trying local database');
        try {
          final localReceipts = await _goodReceiptService.getGoodReceipts(
            fetchFromServer: false,
            fetchItemsFromServer: false,
          );
          
          final receipts = localReceipts.map((data) => GoodReceipt.fromJson(data)).toList();
          
          setState(() {
            _goodReceipts = receipts;
            _isLoading = false;
            _errorMessage = lastError != null ? 'Server connection failed, showing local data' : null;
          });
          
          // Show fallback message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Server connection failed, showing local data'))
            );
          }
        } catch (localError) {
          debugPrint('Local database fetch also failed: $localError');
          setState(() {
            _errorMessage = 'Failed to fetch goods receipts: $lastError';
            _isLoading = false;
          });
          
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading goods receipts: $lastError'))
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Unexpected error in _fetchGoodReceipts: $e');
      setState(() {
        _errorMessage = 'Failed to fetch goods receipts: $e';
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goods receipts: $e'))
        );
      }
    }
  }

  Future<void> _deleteGoodReceipt(String id) async {
    try {
      final success = await _goodReceiptService.deleteGoodReceipt(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goods receipt deleted successfully')),
        );
        _fetchGoodReceipts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete goods receipt')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods Receipt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchGoodReceipts,
            tooltip: 'Refresh from server',
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _fetchGoodReceipts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _goodReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No goods receipts found',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchGoodReceipts,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchGoodReceipts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _goodReceipts.length,
                        itemBuilder: (context, index) {
                          final receipt = _goodReceipts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Dismissible(
                              key: Key(receipt.id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16.0),
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
                                      content: Text('Are you sure you want to delete ${receipt.name}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) {
                                _deleteGoodReceipt(receipt.id);
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(receipt.statusColor).withOpacity(0.2),
                                  child: Text(receipt.name.substring(0, min(2, receipt.name.length))),
                                ),
                                title: Text(receipt.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: ${receipt.createdAt.substring(0, min(10, receipt.createdAt.length))}'),
                                    Text('Supplier: ${receipt.supplierCode}'),
                                  ],
                                ),
                                trailing: Chip(
                                  label: Text(
                                    receipt.statusText,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  backgroundColor: Color(receipt.statusColor),
                                ),
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GoodsReceiptDetailsPage(
                                        receiptId: receipt.id,
                                      ),
                                    ),
                                  );
                                  if (result != null && result == true) {
                                    _fetchGoodReceipts();
                                  }
                                },
                                isThreeLine: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddGoodReceiptDialog(context);
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddGoodReceiptDialog(BuildContext context) {
    final nameController = TextEditingController();
    final supplierCodeController = TextEditingController();
    final whsController = TextEditingController();
    int selectedStatus = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Goods Receipt'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter receipt name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: supplierCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Code',
                        hintText: 'Enter supplier code',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: whsController,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse',
                        hintText: 'Enter warehouse code',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Pending')),
                        DropdownMenuItem(value: 1, child: Text('Received')),
                        DropdownMenuItem(value: 2, child: Text('Verified')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedStatus = value;
                          });
                        }
                      },
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
                    if (nameController.text.isEmpty ||
                        supplierCodeController.text.isEmpty ||
                        whsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }

                    try {
                      await _goodReceiptService.createGoodReceipt(
                        name: nameController.text.trim(),
                        status: selectedStatus,
                        supplierCode: supplierCodeController.text.trim(),
                        whs: whsController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Goods receipt created successfully')),
                        );
                        _fetchGoodReceipts();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating goods receipt: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }
}