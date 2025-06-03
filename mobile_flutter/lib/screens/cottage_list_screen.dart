import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../services/cottage_service.dart';
import 'cottage_detail_screen.dart';

class CottageListScreen extends StatefulWidget {
  const CottageListScreen({super.key});

  @override
  State<CottageListScreen> createState() => _CottageListScreenState();
}

class _CottageListScreenState extends State<CottageListScreen> {
  late Future<List<Cottage>> _cottagesFuture;

  @override
  void initState() {
    super.initState();
    _loadCottages();
  }

  void _loadCottages() {
    _cottagesFuture = Provider.of<CottageService>(context, listen: false).getCottages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Домики'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Cottage>>(
        future: _cottagesFuture,
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
                margin: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CottageDetailScreen(cottageId: cottage.id),
                      ),
                    ).then((_) => setState(() => _loadCottages()));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cottage.images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: cottage.images.length,
                            itemBuilder: (context, imageIndex) {
                              return Image.network(
                                cottage.images[imageIndex],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error, size: 64),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ListTile(
                        title: Text(cottage.name),
                        subtitle: Text(cottage.description),
                        trailing: Text('${cottage.price.toStringAsFixed(2)} ₽/сутки'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
} 