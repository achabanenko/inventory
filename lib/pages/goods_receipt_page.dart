import 'package:flutter/material.dart';
import 'goods_receipt_details_page.dart';

class GoodsReceiptPage extends StatelessWidget {
  const GoodsReceiptPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods Receipt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 10, // Replace with actual receipt count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Text('GR${index + 1}'),
              ),
              title: Text('Receipt #${2000 + index}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${DateTime.now().subtract(Duration(days: index)).toString().substring(0, 10)}'),
                  Text('Supplier: Supplier ${index + 1}'),
                ],
              ),
              trailing: Chip(
                label: Text(
                  index % 3 == 0 ? 'Pending' : (index % 3 == 1 ? 'Received' : 'Verified'),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: index % 3 == 0 
                    ? Colors.orange 
                    : (index % 3 == 1 ? Colors.blue : Colors.green),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoodsReceiptDetailsPage(
                      receiptNumber: '${2000 + index}',
                    ),
                  ),
                );
              },
              isThreeLine: true,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new goods receipt
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 