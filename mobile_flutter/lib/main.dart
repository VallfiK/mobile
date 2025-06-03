import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'screens/home_screen.dart';
import 'screens/cottage_list_screen.dart';
import 'screens/management_screen.dart';
import 'services/api_client.dart';
import 'services/cottage_service.dart';
import 'services/booking_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  
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
        title: 'Управление базой отдыха',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainScreen(),
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CottageListScreen(),
    const ManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Домики',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Управление',
          ),
        ],
      ),
    );
  }
}
