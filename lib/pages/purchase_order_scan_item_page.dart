import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/device_id_service.dart';
import '../services/graphql_service.dart';

class PurchaseOrderScanItemPage extends StatefulWidget {
  final String purchaseOrderId;
  final Function(Map<String, dynamic>) onItemAdded;

  const PurchaseOrderScanItemPage({
    super.key, 
    required this.purchaseOrderId,
    required this.onItemAdded
  });

  @override
  State<PurchaseOrderScanItemPage> createState() =>
      _PurchaseOrderScanItemPageState();
}

class _PurchaseOrderScanItemPageState extends State<PurchaseOrderScanItemPage> {
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set focus to the barcode field when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  void _processBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    // Parse the quantity, default to 1 if invalid
    double quantity = 1;
    try {
      quantity = double.parse(_quantityController.text);
      if (quantity <= 0) quantity = 1; // Ensure quantity is positive
    } catch (e) {
      // If parsing fails, use default quantity of 1
      _quantityController.text = '1';
    }

    // Get the device ID
    final deviceIdService = DeviceIdService();
    final deviceId = await deviceIdService.getDeviceId();

    setState(() {
      _isLoading = true;
    });

    try {
      // Use GraphQL service to add the item to the purchase order
      final addedItem = await _purchaseOrderService.createPurchaseOrderItem(
        purchaseOrderId: widget.purchaseOrderId,
        itemCode: barcode,
        name: 'Item #$barcode', // This would be replaced with actual product lookup
        qty: quantity,
        deviceId: deviceId,
      );

      debugPrint('Added item with device ID: $deviceId');

      // Call the callback to update the UI
      widget.onItemAdded(addedItem);

      // Clear the input field
      _barcodeController.clear();

      // Show a snackbar to confirm the item was added
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item $barcode added to order (Qty: ${_quantityController.text})',
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      // Reset quantity to 1 for next scan
      _quantityController.text = '1';

      // Keep focus on the barcode field for the next scan
      _barcodeFocusNode.requestFocus();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding item: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
        title: const Text('Scan Item'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 32, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Scan or enter an item barcode/SKU code to add it to the purchase order',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Barcode input field
            TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              decoration: InputDecoration(
                labelText: 'Barcode / Item Code / SKU',
                hintText: 'Scan or type barcode here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _barcodeController.clear();
                    _barcodeFocusNode.requestFocus();
                  },
                ),
              ),
              style: const TextStyle(fontSize: 20),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _quantityFocusNode.requestFocus(),
              autofocus: true,
              inputFormatters: [
                // Optional: Add input formatters if needed
                FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
              ],
            ),
            const SizedBox(height: 16),

            // Quantity input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.format_list_numbered),
                    ),
                    style: const TextStyle(fontSize: 20),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted:
                        (_) => _processBarcode(_barcodeController.text),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Only digits
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Quick quantity buttons
                Wrap(
                  spacing: 8,
                  children: [
                    _buildQuantityButton('1'),
                    _buildQuantityButton('5'),
                    _buildQuantityButton('10'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Large Add Item button
            Container(
              height: 70,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: () => _processBarcode(_barcodeController.text),
                icon: const Icon(Icons.add_circle, size: 32),
                label: const Text(
                  'ADD ITEM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recently added items section - could be expanded in the future
            const Text(
              'Recently Added Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: Center(
                child: Text(
                  'Items added to this purchase order will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build quick quantity selection buttons
  Widget _buildQuantityButton(String value) {
    return InkWell(
      onTap: () {
        setState(() {
          _quantityController.text = value;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
