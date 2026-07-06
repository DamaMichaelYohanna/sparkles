import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ServicesPricingScreen extends StatefulWidget {
  const ServicesPricingScreen({Key? key}) : super(key: key);

  @override
  State<ServicesPricingScreen> createState() => _ServicesPricingScreenState();
}

class _ServicesPricingScreenState extends State<ServicesPricingScreen> {
  final List<Map<String, dynamic>> _services = [
    {'id': '1', 'name': 'Wash & Fold', 'price': 2.50, 'unit': 'per lb'},
    {'id': '2', 'name': 'Dry Cleaning', 'price': 5.00, 'unit': 'per item'},
    {'id': '3', 'name': 'Ironing', 'price': 1.50, 'unit': 'per item'},
  ];

  void _showServiceDialog([Map<String, dynamic>? service, int? index]) {
    final isEditing = service != null;
    final nameController = TextEditingController(text: isEditing ? service['name'] : '');
    final priceController = TextEditingController(text: isEditing ? service['price'].toString() : '');
    final unitController = TextEditingController(text: isEditing ? service['unit'] : 'per item');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Service' : 'Add Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Service Name (e.g. Wash & Fold)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price', prefixText: '₦'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: 'Unit (e.g. per lb, per item)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
                final newUnit = unitController.text.trim();

                if (newName.isNotEmpty) {
                  setState(() {
                    if (isEditing && index != null) {
                      _services[index] = {
                        'id': service['id'],
                        'name': newName,
                        'price': newPrice,
                        'unit': newUnit,
                      };
                    } else {
                      _services.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'name': newName,
                        'price': newPrice,
                        'unit': newUnit,
                      });
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteService(int index) {
    setState(() {
      _services.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & Pricing'),
      ),
      body: _services.isEmpty
          ? const Center(child: Text('No services added yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final service = _services[index];
                return ListTile(
                  title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Unit: ${service['unit']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₦${service['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () => _showServiceDialog(service, index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteService(index),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
