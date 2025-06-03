import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/tariff.dart';
import '../services/booking_service.dart';
import 'package:intl/intl.dart';

class BookingDialog extends StatefulWidget {
  final String cottageId;
  final DateTime initialDate;
  final Function(Booking) onBookingCreated;
  final BookingService bookingService;

  const BookingDialog({
    super.key,
    required this.cottageId,
    required this.initialDate,
    required this.onBookingCreated,
    required this.bookingService,
  });

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _guestNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _endDate;
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
    _loadTariffs();
  }

  Future<void> _loadTariffs() async {
    try {
      setState(() => _isLoading = true);
      final tariffs = await widget.bookingService.getTariffs();
      
      if (tariffs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет доступных тарифов')),
          );
        }
        return;
      }

      setState(() {
        _tariffs = tariffs;
        _selectedTariffId = tariffs.isNotEmpty ? int.tryParse(tariffs[0].id) : null;
        _isLoading = false;
      });
      
      // Рассчитываем начальную стоимость, если выбрана дата выезда
      if (_endDate != null) {
        _calculateCost();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки тарифов: $e')),
        );
      }
    }
  }

  void _calculateCost() {
    if (_endDate == null || _selectedTariffId == null) return;

    final selectedTariff = _tariffs.firstWhere(
      (t) => int.tryParse(t.id) == _selectedTariffId,
      orElse: () => _tariffs.first,
    );

    // Устанавливаем время заезда (14:00) и выезда (12:00)
    final checkInDateTime = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      14, // 14:00
    );

    final checkOutDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      12, // 12:00
    );

    // Рассчитываем количество суток
    final difference = checkOutDateTime.difference(checkInDateTime);
    final days = (difference.inHours / 24).ceil(); // Округляем вверх до полных суток

    // Рассчитываем общую стоимость
    final total = selectedTariff.pricePerDay * days;
    final deposit = total * 0.3; // 30% предоплата
    final remainingPayment = total - deposit;

    setState(() {
      _totalCost = total;
      _requiredDeposit = deposit;
      _remainingPayment = remainingPayment;
    });
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate() || _endDate == null || _selectedTariffId == null) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      final selectedTariff = _tariffs.firstWhere(
        (t) => int.tryParse(t.id) == _selectedTariffId,
        orElse: () => _tariffs.first,
      );

      final booking = Booking(
        id: '',
        cottageId: widget.cottageId,
        startDate: widget.initialDate,
        endDate: _endDate!,
        guests: _guests,
        status: 'booked',
        guestName: _guestNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        notes: _notesController.text,
        totalCost: _totalCost,
        tariffId: selectedTariff.id.toString(),
      );

      final createdBooking = await widget.bookingService.createBooking(booking);

      if (mounted) {
        widget.onBookingCreated(createdBooking);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бронирование успешно создано!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания бронирования: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 2,
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Новое бронирование',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _guestNameController,
                    decoration: const InputDecoration(
                      labelText: 'ФИО гостя',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите ФИО гостя';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Пожалуйста, введите телефон';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Дата заезда: ${DateFormat('dd.MM.yyyy').format(widget.initialDate)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? widget.initialDate.add(const Duration(days: 1)),
                            firstDate: widget.initialDate.add(const Duration(days: 1)),
                            lastDate: widget.initialDate.add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                            _calculateCost();
                          }
                        },
                        child: Text(_endDate == null
                            ? 'Выбрать дату выезда'
                            : 'Дата выезда: ${DateFormat('dd.MM.yyyy').format(_endDate!)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Количество гостей:'),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _guests,
                        items: List.generate(10, (index) => index + 1)
                            .map((count) => DropdownMenuItem(
                                  value: count,
                                  child: Text(count.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _guests = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    DropdownButtonFormField<int>(
                      value: _selectedTariffId,
                      decoration: const InputDecoration(
                        labelText: 'Тариф',
                        border: OutlineInputBorder(),
                      ),
                      items: _tariffs
                          .map((tariff) => DropdownMenuItem(
                                value: int.tryParse(tariff.id),
                                child: Text('${tariff.name} - ${currencyFormat.format(tariff.pricePerDay)} в сутки'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedTariffId = value);
                        _calculateCost();
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Пожалуйста, выберите тариф';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  if (_totalCost > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Расчет стоимости:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Общая стоимость: ${currencyFormat.format(_totalCost)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Divider(),
                          Text(
                            'Предоплата (30%): ${currencyFormat.format(_requiredDeposit)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Оплата при заселении: ${currencyFormat.format(_remainingPayment)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Примечания',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Отмена'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createBooking,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Создать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 