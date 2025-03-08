import 'package:flutter/material.dart';
import '../services/graphql_service.dart';

class PrintLabelsDetailsPage extends StatefulWidget {
  final String batchNumber;
  final Map<String, dynamic>? labelBatch;

  const PrintLabelsDetailsPage({
    super.key,
    required this.batchNumber,
    this.labelBatch,
  });

  @override
  State<PrintLabelsDetailsPage> createState() => _PrintLabelsDetailsPageState();
}

class _PrintLabelsDetailsPageState extends State<PrintLabelsDetailsPage> {
  final PrintLabelService _printLabelService = PrintLabelService();
  Map<String, dynamic>? _labelBatch;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _labelBatch = widget.labelBatch;
    if (_labelBatch == null) {
      _loadLabelBatch();
    }
  }

  Future<void> _loadLabelBatch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use GraphQL service to fetch the label batch
      final filter = {'id': widget.batchNumber};
      final labels = await _printLabelService.getPrintLabels(filter: filter);
      if (labels.isNotEmpty) {
        setState(() {
          _labelBatch = labels.first;
        });
      } else {
        setState(() {
          _errorMessage = 'Label batch not found';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load label batch: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Label Batch #${widget.batchNumber}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLabelBatch,
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
                        onPressed: _loadLabelBatch,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _labelBatch == null
                  ? const Center(child: Text('No label batch data available'))
                  : Column(
        children: [
          // Batch Summary Card
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
                        'Label Type:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_getLabelType(_labelBatch?['status'] ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Created:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_formatDate(_labelBatch?['createdAt'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Labels:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${_labelBatch?['items']?.length ?? 0} items'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Scanned Items Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scanned Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    // TODO: Implement barcode scanner to add new items
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Barcode scanner not implemented yet')),
                    );
                  },
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
          // Scanned Items List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _labelBatch?['items']?.length ?? 0,
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Product Image or Barcode Icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.qr_code_2, color: Colors.purple.shade300, size: 32),
                        ),
                        const SizedBox(width: 16),
                        // Product Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _labelBatch?['items'][index]['name'] ?? 'Unknown Product',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Item Code: ${_labelBatch?['items'][index]['itemCode'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontFamily: 'Courier',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Qty: ${_labelBatch?['items'][index]['qty'] ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () {
                                          // TODO: Implement edit functionality
                                        },
                                        color: Colors.blue,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () {
                                          // TODO: Implement delete functionality
                                        },
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
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
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Print functionality using GraphQL
                      if (_labelBatch != null) {
                        try {
                          // Update the status to 'Printed'
                          await _printLabelService.updatePrintLabel(
                            id: _labelBatch!['id'],
                            status: 2, // Printed status
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Labels sent to printer')),
                          );
                          
                          // Refresh the data
                          _loadLabelBatch();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error printing labels: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print All Labels'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
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

  String _getLabelType(int number) {
    switch (number % 4) {
      case 0:
        return 'Product Labels';
      case 1:
        return 'Shelf Labels';
      case 2:
        return 'Barcode Labels';
      case 3:
        return 'Price Tags';
      default:
        return 'Custom Labels';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
} 