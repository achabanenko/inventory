import 'package:flutter/material.dart';
import 'print_labels_details_page.dart';

class PrintLabelsPage extends StatelessWidget {
  const PrintLabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Labels'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 10, // Replace with actual batch count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: Text('LB${index + 1}'),
              ),
              title: Text('Batch #${4000 + index}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created: ${DateTime.now().subtract(Duration(days: index)).toString().substring(0, 10)}'),
                  Text('Label Type: ${_getLabelType(index)}'),
                  Text('Quantity: ${((index + 1) * 50)} labels'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(
                      index % 2 == 0 ? 'Pending' : 'Printed',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: index % 2 == 0 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () {
                      // TODO: Implement print functionality
                    },
                    color: Colors.purple,
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrintLabelsDetailsPage(
                      batchNumber: '${4000 + index}',
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
          // TODO: Add new label batch
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _getLabelType(int index) {
    switch (index % 4) {
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
} 