import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../models/tariff.dart';
import '../services/booking_service.dart';
import 'package:intl/intl.dart';

class BookingDialog extends StatefulWidget {
  final String cottageId;
  final DateTime selectedDate;
  final Function(Booking) onBookingCreated;
  final BookingService bookingService;

  const BookingDialog({
    super.key,
    required this.cottageId,
    required this.selectedDate,
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
  final _prepaymentController = TextEditingController();
  
  DateTime? _endDate;
  int _guests = 1;
  int? _selectedTariffId;
  List<Tariff> _tariffs = [];
  bool _isLoading = false;
  bool _isCreatingBooking = false; // Добавляем флаг для предотвращения дублирования
  double _totalCost = 0;
  double _requiredDeposit = 0;
  double _remainingPayment = 0;

  @override
  void initState() {
    super.initState();
    // Сохраняем время заезда, если оно есть (например, 14:00)
    final checkInDate = widget.selectedDate;
    // По умолчанию выезд на следующий день в 12:00
    _endDate = DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
      checkInDate.hour,
      checkInDate.minute,
    ).add(const Duration(days: 1));
    // Если заезд ровно в 14:00, выезд делаем в 12:00 следующего дня
    if (checkInDate.hour == 14 && checkInDate.minute == 0) {
      _endDate = DateTime(
        checkInDate.add(const Duration(days: 1)).year,
        checkInDate.add(const Duration(days: 1)).month,
        checkInDate.add(const Duration(days: 1)).day,
        12, 0,
      );
    }
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
      
      // Рассчитываем начальную стоимость
      _calculateCost();
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
    if (_endDate == null || _selectedTariffId == null || _tariffs.isEmpty) return;

    final selectedTariff = _tariffs.firstWhere(
      (t) => int.tryParse(t.id) == _selectedTariffId,
      orElse: () => _tariffs.first,
    );

    // Устанавливаем время заезда (14:00) и выезда (12:00)
    final checkInDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
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
      // Устанавливаем значение предоплаты в контроллер
      _prepaymentController.text = deposit.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _prepaymentController.dispose();
    super.dispose();
  }

  Future<void> _createBooking() async {
    // Проверяем, не выполняется ли уже создание бронирования
    if (_isCreatingBooking) {
      print('Booking creation already in progress, ignoring duplicate call');
      return;
    }

    if (!_formKey.currentState!.validate() || _endDate == null || _selectedTariffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните все обязательные поля')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _isCreatingBooking = true; // Устанавливаем флаг
      });

      print('\n=== BOOKING DIALOG DEBUG ===');
      print('Cottage ID: ${widget.cottageId}');
      print('Guest Name: ${_guestNameController.text}');
      print('Phone: ${_phoneController.text}');
      print('Email: ${_emailController.text}');
      print('Start Date: ${widget.selectedDate}');
      print('End Date: $_endDate');
      print('Guests: $_guests');
      print('Selected Tariff ID: $_selectedTariffId');
      print('Total Cost: $_totalCost');
      print('Prepayment: ${_prepaymentController.text}');

      // Нормализуем даты с правильным временем
      final normalizedCheckInDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        14, // 14:00
      );
      
      final normalizedCheckOutDate = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        12, // 12:00
      );

      print('Normalized Check-in: $normalizedCheckInDate');
      print('Normalized Check-out: $normalizedCheckOutDate');

      final booking = Booking(
        id: '',
        cottageId: widget.cottageId,
        startDate: normalizedCheckInDate,
        endDate: normalizedCheckOutDate,
        guests: _guests,
        status: 'booked',
        guestName: _guestNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        notes: _notesController.text.trim(),
        totalCost: _totalCost,
        prepayment: double.tryParse(_prepaymentController.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.')) ?? 0.0,
        tariffId: _selectedTariffId.toString(),
      );

      print('Booking object created: ${booking.toJson()}');

      final createdBooking = await widget.bookingService.createBooking(booking);
      // Принудительно обновляем данные с сервера
      await widget.bookingService.refreshBookingsForCottage(widget.cottageId);
      
      if (mounted) {
        Navigator.of(context).pop();
        
        // Затем вызываем колбэк
        widget.onBookingCreated(createdBooking);
        
        // И показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бронирование успешно создано!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания бронирования: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCreatingBooking = false; // Сбрасываем флаг
        });
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

    return Dialog.fullscreen(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Новое бронирование',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text('Домик ID: ${widget.cottageId}'),
                    subtitle: Text('Дата заезда: ${DateFormat('dd.MM.yyyy').format(widget.selectedDate)} в 14:00'),
                  ),
                ),
                const SizedBox(height: 16),

                // ФИО гостя
                TextFormField(
                  controller: _guestNameController,
                  decoration: const InputDecoration(
                    labelText: 'ФИО гостя *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите ФИО гостя';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Телефон
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите телефон';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // Дата выезда
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Дата выезда *'),
                  subtitle: Text(_endDate == null
                      ? 'Выберите дату выезда'
                      : '${DateFormat('dd.MM.yyyy').format(_endDate!)} в 12:00'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? widget.selectedDate.add(const Duration(days: 1)),
                      firstDate: widget.selectedDate.add(const Duration(days: 1)),
                      lastDate: widget.selectedDate.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                      _calculateCost();
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Количество гостей
                Row(
                  children: [
                    const Text('Количество гостей: '),
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
                
                // Тариф
                if (_isLoading && _tariffs.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (_tariffs.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: _selectedTariffId,
                    decoration: const InputDecoration(
                      labelText: 'Тариф *',
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
                
                // Расчет стоимости
                if (_totalCost > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
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
                
                // Предоплата
                TextFormField(
                  controller: _prepaymentController,
                  decoration: const InputDecoration(
                    labelText: 'Предоплата *',
                    hintText: 'Введите сумму предоплаты',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите сумму предоплаты';
                    }
                    final amount = double.tryParse(value.replaceAll(',', '.'));
                    if (amount == null || amount < 0) {
                      return 'Введите корректную сумму';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Обновляем оставшуюся сумму при изменении предоплаты
                    if (value.isNotEmpty) {
                      final prepayment = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                      setState(() {
                        _remainingPayment = _totalCost - prepayment;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Примечания
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Примечания',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                // Кнопки
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: (_isLoading || _isCreatingBooking) ? null : _createBooking,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Создать бронирование'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}