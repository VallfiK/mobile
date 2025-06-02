import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../services/api_client.dart';
import '../services/cottage_service.dart';
import '../services/booking_service.dart';
import 'cottage_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final isConnected = await apiClient.testConnection();
    setState(() {
      _isConnected = isConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('База Отдыха'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Не удалось подключиться к серверу'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkConnection,
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

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
    print('CottageList build');
    final cottageService = Provider.of<CottageService>(context, listen: false);
    print('CottageService obtained');
    
    return FutureBuilder<List<Cottage>>(
      future: cottageService.getCottages(),
      builder: (context, snapshot) {
        print('Snapshot state: ${snapshot.connectionState}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Waiting for data...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final cottages = snapshot.data ?? [];
        print('Received cottages: ${cottages.length}');
        return ListView.builder(
          itemCount: cottages.length,
          itemBuilder: (context, index) {
            final cottage = cottages[index];
            print('Building cottage item: ${cottage.name}');
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
