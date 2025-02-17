import 'package:flutter/material.dart';
import 'purchase_order_details_page.dart';

class PurchaseOrderPage extends StatelessWidget {
  const PurchaseOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 10, // Replace with actual order count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text('PO${index + 1}'),
              ),
              title: Text('Order #${1000 + index}'),
              subtitle: Text('Date: ${DateTime.now().subtract(Duration(days: index)).toString().substring(0, 10)}'),
              trailing: Chip(
                label: Text(
                  index % 2 == 0 ? 'Pending' : 'Completed',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: index % 2 == 0 ? Colors.orange : Colors.green,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseOrderDetailsPage(
                      orderNumber: '${1000 + index}',
                    ),
                  ),
                );
              },
            ),
          );
        },
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