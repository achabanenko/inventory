import 'package:flutter/material.dart';
import 'stock_take_details_page.dart';

class StockTakePage extends StatelessWidget {
  const StockTakePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Take'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 10, // Replace with actual stock take count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text('ST${index + 1}'),
              ),
              title: Text('Stock Take #${3000 + index}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${DateTime.now().subtract(Duration(days: index)).toString().substring(0, 10)}'),
                  Text('Location: Warehouse ${(index % 3) + 1}'),
                  Text('Items: ${((index + 1) * 25)} products'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      index % 4 == 0 ? 'Draft' 
                          : (index % 4 == 1 ? 'In Progress' 
                          : (index % 4 == 2 ? 'Reviewing' : 'Completed')),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: index % 4 == 0 
                        ? Colors.grey 
                        : (index % 4 == 1 ? Colors.blue 
                        : (index % 4 == 2 ? Colors.orange : Colors.green)),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StockTakeDetailsPage(
                      batchNumber: '${3000 + index}',
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
          // TODO: Add new stock take
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 