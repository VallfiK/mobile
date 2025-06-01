import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'services/cottage_service.dart';
import 'services/booking_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'База Отдыха',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MultiProvider(
        providers: [
          Provider<ApiClient>(
            create: (_) => ApiClient(),
            dispose: (_, client) => client.dispose(),
          ),
          ProxyProvider<ApiClient, CottageService>(
            update: (_, apiClient, __) => CottageService(apiClient),
          ),
          ProxyProvider<ApiClient, BookingService>(
            update: (_, apiClient, __) => BookingService(apiClient),
          ),
        ],
        child: const HomeScreen(),
      ),
    );
  }
}
