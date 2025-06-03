import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/booking_service.dart';
import '../models/tariff.dart';

class TariffManagementTab extends StatefulWidget {
  const TariffManagementTab({super.key});

  @override
  State<TariffManagementTab> createState() => _TariffManagementTabState();
}

class _TariffManagementTabState extends State<TariffManagementTab> {
  late Future<List<Tariff>> _tariffsFuture;

  @override
  void initState() {
    super.initState();
    _loadTariffs();
  }

  void _loadTariffs() {
    _tariffsFuture = Provider.of<BookingService>(context, listen: false).getTariffs();
  }

  Future<void> _showTariffDialog([Tariff? tariff]) async {
    final nameController = TextEditingController(text: tariff?.name ?? '');
    final priceController = TextEditingController(text: tariff?.pricePerDay.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tariff == null ? 'Добавить тариф' : 'Редактировать тариф'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название тарифа'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Цена за сутки'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final price = double.tryParse(priceController.text) ?? 0;
                final bookingService = Provider.of<BookingService>(context, listen: false);

                if (tariff == null) {
                  await bookingService.createTariff(
                    name: nameController.text,
                    pricePerDay: price,
                  );
                } else {
                  await bookingService.updateTariff(
                    tariffId: tariff.id,
                    name: nameController.text,
                    pricePerDay: price,
                  );
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  setState(() {
                    _loadTariffs();
                  });
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(tariff == null ? 'Добавить' : 'Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tariff>>(
      future: _tariffsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final tariffs = snapshot.data ?? [];

        return Stack(
          children: [
            ListView.builder(
              itemCount: tariffs.length,
              padding: const EdgeInsets.only(bottom: 80),
              itemBuilder: (context, index) {
                final tariff = tariffs[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(tariff.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${tariff.pricePerDay.toStringAsFixed(2)} ₽/сутки'),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showTariffDialog(tariff),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Подтверждение'),
                                content: const Text('Вы уверены, что хотите удалить этот тариф?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Удалить'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await Provider.of<BookingService>(context, listen: false)
                                    .deleteTariff(tariff.id);
                                setState(() {
                                  _loadTariffs();
                                });
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _showTariffDialog(),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
} 