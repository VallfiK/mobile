import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'services/cottage_service.dart';
import 'services/booking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Настройка HTTP-клиента для работы с локальным сервером
  final client = http.Client();
  
  // Настройка для работы с нешифрованным трафиком
  if (Platform.isAndroid) {
    HttpOverrides.global = MyHttpOverrides();
  }

  // Проверяем подключение к серверу
  final apiClient = ApiClient(client: client);
  try {
    print('Checking server connection...');
    final isConnected = await apiClient.testConnection();
    print('Server connection result: $isConnected');
  } catch (e) {
    print('Connection check failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => apiClient,
          dispose: (_, client) => client.dispose(),
        ),
        ProxyProvider<ApiClient, CottageService>(
          update: (_, apiClient, __) => CottageService(apiClient),
        ),
        ProxyProvider<ApiClient, BookingService>(
          update: (_, apiClient, __) => BookingService(apiClient),
        ),
      ],
      child: MaterialApp(
        title: 'База Отдыха',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
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
