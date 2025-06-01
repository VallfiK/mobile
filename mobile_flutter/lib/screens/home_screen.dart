import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../services/cottage_service.dart';
import 'cottage_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База Отдыха'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const CottageList(),
    );
  }
}

class CottageList extends StatelessWidget {
  const CottageList({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cottage>>(
      future: Provider.of<CottageService>(context, listen: false).getCottages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final cottages = snapshot.data ?? [];
        return ListView.builder(
          itemCount: cottages.length,
          itemBuilder: (context, index) {
            final cottage = cottages[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: cottage.images.isNotEmpty
                    ? Image.network(
                        cottage.images.first,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.house),
                title: Text(cottage.name),
                subtitle: Text('${cottage.price} ₽ в сутки'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CottageDetailScreen(
                        cottageId: cottage.id,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
