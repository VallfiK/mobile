import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../models/booking.dart';
import '../services/cottage_service.dart';
import '../services/booking_service.dart';
import '../widgets/calendar_view.dart';
import '../widgets/booking_date_picker.dart';
import '../widgets/booking_filters.dart';

class CottageDetailScreen extends StatefulWidget {
  final String cottageId;

  const CottageDetailScreen({super.key, required this.cottageId});

  @override
  State<CottageDetailScreen> createState() => _CottageDetailScreenState();
}

class _CottageDetailScreenState extends State<CottageDetailScreen> {
  late Future<Cottage> _cottageFuture;
  late Future<List<Booking>> _bookingsFuture;
  DateTime _checkInDate = DateTime.now();
  DateTime? _checkOutDate;
  int _guests = 1;
  String _name = '';
  String _phone = '';
  String _email = '';
  bool _isLoading = false;
  List<Booking> _filteredBookings = [];

  @override
  void initState() {
    super.initState();
    _cottageFuture = Provider.of<CottageService>(context, listen: false)
        .getCottage(widget.cottageId);
    _bookingsFuture = Provider.of<BookingService>(context, listen: false)
        .getBookingsByCottage(widget.cottageId);
  }

  Future<void> _createBooking() async {
    if (_checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату выезда')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final booking = Booking(
        id: '', // будет сгенерирован на сервере
        cottageId: widget.cottageId,
        startDate: _checkInDate,
        endDate: _checkOutDate!,
        userId: 'admin', // администратор
        guestName: _name.isNotEmpty ? _name : 'Гость',
        phone: _phone,
        email: _email,
        guests: _guests,
      );

      await Provider.of<BookingService>(context, listen: false)
          .createBooking(booking);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно создано!')),
      );

      setState(() {
        _checkInDate = DateTime.now();
        _checkOutDate = null;
        _guests = 1;
        _name = '';
        _phone = '';
        _email = '';
        _bookingsFuture = Provider.of<BookingService>(context, listen: false)
            .getBookingsByCottage(widget.cottageId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<BookingService>(context, listen: false)
          .cancelBooking(bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно отменено!')),
      );

      setState(() {
        _bookingsFuture = Provider.of<BookingService>(context, listen: false)
            .getBookingsByCottage(widget.cottageId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters(List<Booking> filteredBookings) {
    setState(() {
      _filteredBookings = filteredBookings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Домик'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Cottage>(
        future: _cottageFuture,
        builder: (context, cottageSnapshot) {
          if (cottageSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cottageSnapshot.hasError) {
            return Center(child: Text('Ошибка: ${cottageSnapshot.error}'));
          }

          if (!cottageSnapshot.hasData) {
            return const Center(child: Text('Домик не найден'));
          }

          final cottage = cottageSnapshot.data!;
          return FutureBuilder<List<Booking>>(
            future: _bookingsFuture,
            builder: (context, bookingsSnapshot) {
              if (bookingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (bookingsSnapshot.hasError) {
                return Center(child: Text('Ошибка: ${bookingsSnapshot.error}'));
              }

              final bookings = bookingsSnapshot.data ?? [];
              if (_filteredBookings.isEmpty) {
                _filteredBookings = bookings;
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageGallery(cottage.images),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cottage.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Цена: ${cottage.price} ₽ в сутки',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Вместимость: ${cottage.capacity} человек',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            cottage.description.isNotEmpty 
                                ? cottage.description 
                                : 'Описание отсутствует',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          BookingFilters(
                            bookings: bookings,
                            onFilterApplied: _applyFilters,
                          ),
                          const SizedBox(height: 24),
                          CalendarView(
                            cottage: cottage,
                            bookings: _filteredBookings,
                            onCancelBooking: _cancelBooking,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Создать бронирование',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildBookingForm(cottage),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingForm(Cottage cottage) {
    return Column(
      children: [
        BookingDatePicker(
          initialDate: _checkInDate,
          onDateSelected: (date) {
            setState(() {
              _checkInDate = date;
              if (_checkOutDate != null &&
                  _checkOutDate!.isBefore(date)) {
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
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Имя гостя',
            prefixIcon: Icon(Icons.person),
          ),
          initialValue: _name,
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
          onChanged: (value) => _email = value,
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
              'Максимум ${cottage.capacity} гостей',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Итоговая стоимость: ${_calculateTotalPrice(cottage)} ₽',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createBooking,
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
        ),
      ],
    );
  }

  int _calculateTotalPrice(Cottage cottage) {
    if (_checkOutDate == null) return 0;
    final nights = _checkOutDate!.difference(_checkInDate).inDays;
    return cottage.price.toInt() * nights;
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.house, size: 64, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.error, size: 64, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}