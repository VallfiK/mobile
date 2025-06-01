import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../widgets/booking_date_picker.dart';
import 'package:intl/intl.dart';

class BookingFormScreen extends StatefulWidget {
  final String cottageId;
  final Cottage cottage;

  const BookingFormScreen({
    super.key,
    required this.cottageId,
    required this.cottage,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _checkInDate = DateTime.now();
  DateTime? _checkOutDate;
  int _guests = 1;
  String _name = '';
  String _phone = '';
  String _email = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkInDate = DateTime.now();
  }

  Future<void> _submitBooking() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final booking = Booking(
          id: '', // будет сгенерирован на сервере
          cottageId: widget.cottageId,
          startDate: _checkInDate,
          endDate: _checkOutDate!,
          guests: _guests,
          userId: 'current_user_id', // нужно будет получить из аутентификации
        );

        await Provider.of<BookingService>(context, listen: false)
            .createBooking(booking);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бронирование успешно создано!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cottage.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.cottage.price} ₽ в сутки',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BookingDatePicker(
                  initialDate: _checkInDate,
                  onDateSelected: (date) {
                    setState(() {
                      _checkInDate = date;
                      if (_checkOutDate != null && _checkOutDate!.isBefore(date)) {
                        _checkOutDate = date.add(const Duration(days: 1));
                      }
                    });
                  },
                  availableDates: [], // TODO: Получить доступные даты с сервера
                ),
                const SizedBox(height: 16),
                BookingDatePicker(
                  initialDate: _checkOutDate ??
                      _checkInDate.add(const Duration(days: 1)),
                  onDateSelected: (date) {
                    setState(() => _checkOutDate = date);
                  },
                  availableDates: [], // TODO: Получить доступные даты с сервера
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Количество гостей',
                          prefixIcon: Icon(Icons.people),
                        ),
                        initialValue: _guests.toString(),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите количество гостей';
                          }
                          final guests = int.tryParse(value);
                          if (guests == null || guests < 1) {
                            return 'Введите корректное количество гостей';
                          }
                          if (guests > widget.cottage.capacity) {
                            return 'Превышен лимит гостей';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final guests = int.tryParse(value);
                          if (guests != null && guests > 0) {
                            setState(() => _guests = guests);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Максимум ${widget.cottage.capacity} гостей',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person),
                  ),
                  initialValue: _name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите ваше имя';
                    }
                    return null;
                  },
                  onChanged: (value) => _name = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  initialValue: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите ваш телефон';
                    }
                    return null;
                  },
                  onChanged: (value) => _phone = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  initialValue: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите ваш email';
                    }
                    if (!value.contains('@')) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                  onChanged: (value) => _email = value,
                ),
                const SizedBox(height: 24),
                Text(
                  'Итоговая стоимость: ${_calculateTotalPrice()} ₽',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Забронировать'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateTotalPrice() {
    if (_checkOutDate == null) return 0;
    final nights = _checkOutDate!.difference(_checkInDate).inDays;
    return widget.cottage.price.toInt() * nights;
  }
}
