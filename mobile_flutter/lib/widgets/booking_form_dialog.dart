import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/cottage.dart';
import '../models/tariff.dart';
import '../services/booking_service.dart';
import 'package:intl/intl.dart';

class BookingFormDialog extends StatefulWidget {
  final Cottage cottage;
  final DateTime selectedDate;
  final Function(Booking) onSubmit;
  final BookingService bookingService;

  const BookingFormDialog({
    super.key,
    required this.cottage,
    required this.selectedDate,
    required this.onSubmit,
    required this.bookingService,
  });

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _checkInDate;
  late DateTime _checkOutDate;
  String _guestName = '';
  String _phone = '';
  String _email = '';
  int _guests = 1;
  int? _selectedTariffId;
  List<Tariff> _tariffs = [];
  bool _isLoading = false;
  double _totalCost = 0;
  double _requiredDeposit = 0;
  double _remainingPayment = 0;

  @override
  void initState() {
    super.initState();
    _checkInDate = widget.selectedDate;
    _checkOutDate = widget.selectedDate.add(const Duration(days: 1));
    _loadTariffs();
  }

  Future<void> _loadTariffs() async {
    try {
      setState(() => _isLoading = true);
      final tariffs = await widget.bookingService.getTariffs();
      
      if (mounted) {
        setState(() {
          _tariffs = tariffs;
          if (tariffs.isNotEmpty) {
            _selectedTariffId = int.tryParse(tariffs[0].id);
            _calculateCost();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки тарифов: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateCost() {
    if (_selectedTariffId == null) return;

    final selectedTariff = _tariffs.firstWhere(
      (t) => int.tryParse(t.id) == _selectedTariffId,
      orElse: () => _tariffs[0],
    );

    final days = _checkOutDate.difference(_checkInDate).inDays;
    final totalCost = selectedTariff.pricePerDay * days;
    
    setState(() {
      _totalCost = totalCost;
      _requiredDeposit = totalCost * 0.3; // 30% предоплата
      _remainingPayment = totalCost - _requiredDeposit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );

    return AlertDialog(
      title: const Text('Новое бронирование'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Информация о домике
                Card(
                  child: ListTile(
                    title: Text(widget.cottage.name),
                    subtitle: Text('ID: ${widget.cottage.id}'),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Даты заезда и выезда
                ListTile(
                  title: const Text('Дата заезда *'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(_checkInDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _checkInDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _checkInDate = date;
                        if (_checkOutDate.isBefore(_checkInDate)) {
                          _checkOutDate = _checkInDate.add(const Duration(days: 1));
                        }
                        _calculateCost();
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Дата выезда *'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(_checkOutDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _checkOutDate,
                      firstDate: _checkInDate.add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _checkOutDate = date;
                        _calculateCost();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // ФИО гостя
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'ФИО гостя *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите ФИО гостя';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _guestName = value),
                ),
                const SizedBox(height: 16),
                
                // Телефон
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Телефон *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите номер телефона';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _phone = value),
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => setState(() => _email = value),
                ),
                const SizedBox(height: 16),

                // Количество гостей
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Количество гостей *',
                    prefixIcon: Icon(Icons.group),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, укажите количество гостей';
                    }
                    final guests = int.tryParse(value);
                    if (guests == null || guests < 1) {
                      return 'Количество гостей должно быть больше 0';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() => _guests = int.tryParse(value) ?? 1),
                ),
                const SizedBox(height: 16),

                // Выбор тарифа
                if (_tariffs.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Тариф *',
                      prefixIcon: Icon(Icons.monetization_on),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedTariffId,
                    items: _tariffs.map((tariff) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(tariff.id),
                        child: Text('${tariff.name} - ${currencyFormat.format(tariff.pricePerDay)}/сутки'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTariffId = value;
                        _calculateCost();
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Пожалуйста, выберите тариф';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Стоимость
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Стоимость проживания:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Общая стоимость: ${currencyFormat.format(_totalCost)}'),
                        Text('Предоплата (30%): ${currencyFormat.format(_requiredDeposit)}'),
                        Text('Остаток к оплате: ${currencyFormat.format(_remainingPayment)}'),
                        const SizedBox(height: 8),
                        Text(
                          'Заезд: 14:00, Выезд: 12:00',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedTariffId != null) {
              // Validate required fields first
              if (_guestName.isEmpty || _phone.isEmpty || widget.cottage.id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пожалуйста, заполните все обязательные поля')),
                );
                return;
              }

              // Validate dates
              if (_checkInDate.isAfter(_checkOutDate)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Дата заезда не может быть позже даты выезда')),
                );
                return;
              }

              print('\n=== FORM DATA BEFORE BOOKING CREATION ===');
              print('Cottage ID: "${widget.cottage.id}"');
              print('Cottage Name: "${widget.cottage.name}"');
              print('Guest Name: "$_guestName"');
              print('Phone: "$_phone"');
              print('Email: "$_email"');
              print('Check-in date: "${_checkInDate}"');
              print('Check-out date: "${_checkOutDate}"');
              print('Guests: $_guests');
              print('Total Cost: $_totalCost');
              print('Tariff ID: "${_selectedTariffId}"');
              print('=== END FORM DATA ===\n');

              // Нормализуем даты, убирая время и устанавливая правильное время заезда/выезда
              final normalizedCheckInDate = DateTime(
                _checkInDate.year,
                _checkInDate.month,
                _checkInDate.day,
                14, // Время заезда - 14:00
              );
              
              final normalizedCheckOutDate = DateTime(
                _checkOutDate.year,
                _checkOutDate.month,
                _checkOutDate.day,
                12, // Время выезда - 12:00
              );

              print('\n=== NORMALIZED DATES ===');
              print('Normalized Check-in: "${normalizedCheckInDate.toIso8601String()}"');
              print('Normalized Check-out: "${normalizedCheckOutDate.toIso8601String()}"');
              print('=== END NORMALIZED DATES ===\n');

              try {
                final booking = Booking(
                  id: '',
                  cottageId: widget.cottage.id,
                  startDate: normalizedCheckInDate,
                  endDate: normalizedCheckOutDate,
                  guests: _guests,
                  status: 'booked',
                  guestName: _guestName.trim(),
                  phone: _phone.trim(),
                  email: _email.trim(),
                  notes: '',
                  totalCost: _totalCost,
                  tariffId: _selectedTariffId?.toString() ?? '1',
                );

                widget.onSubmit(booking);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка при создании бронирования: $e')),
                );
              }
            }
          },
          child: const Text('Забронировать'),
        ),
      ],
    );
  }
} 