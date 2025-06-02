import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../models/booking.dart';
import '../services/cottage_service.dart';
import '../services/booking_service.dart';
import '../widgets/calendar_view.dart';
import '../widgets/booking_filters.dart';
import 'package:intl/intl.dart';

class CottageDetailScreen extends StatefulWidget {
  final String cottageId;

  const CottageDetailScreen({super.key, required this.cottageId});

  @override
  State<CottageDetailScreen> createState() => _CottageDetailScreenState();
}

class _CottageDetailScreenState extends State<CottageDetailScreen> {
  late Cottage _currentCottage;
  late Future<Cottage> _cottageFuture;
  late Future<List<Booking>> _bookingsFuture;
  DateTime _checkInDate = DateTime.now();
  DateTime? _checkOutDate;
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
    if (_checkOutDate == null || _checkInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату заезда и выезда')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final totalCost = await _calculateTotalPrice();
      final booking = Booking(
        id: '', // будет сгенерирован на сервере
        cottageId: widget.cottageId,
        startDate: _checkInDate,
        endDate: _checkOutDate!,
        userId: 'admin', // администратор
        guestName: _name,
        guestPhone: _phone,
        guestEmail: _email,
        totalCost: totalCost,
      );

      await Provider.of<BookingService>(context, listen: false)
          .createBooking(booking);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно создано!')),
      );

      setState(() {
        _checkInDate = DateTime.now();
        _checkOutDate = null;
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

          final cottage = cottageSnapshot.data!;
          _currentCottage = cottage; // Сохраняем коттедж в стейт
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
              _filteredBookings = bookings;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageGallery(cottage.images),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cottage.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (cottage.description != null && cottage.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                cottage.description!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
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
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Имя',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  initialValue: _name,
                                  onChanged: (value) => setState(() => _name = value),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Телефон',
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                  initialValue: _phone,
                                  keyboardType: TextInputType.phone,
                                  onChanged: (value) => setState(() => _phone = value),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            initialValue: _email,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) => setState(() => _email = value),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: TextEditingController(text: DateFormat('dd MMMM yyyy', 'ru_RU').format(_checkInDate)),
                                  decoration: const InputDecoration(
                                    labelText: 'Дата заезда',
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _checkInDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _checkInDate = picked;
                                        if (_checkOutDate != null && _checkOutDate!.isBefore(picked)) {
                                          _checkOutDate = picked.add(const Duration(days: 1));
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: TextEditingController(text: _checkOutDate != null ? DateFormat('dd MMMM yyyy', 'ru_RU').format(_checkOutDate!) : ''),
                                  decoration: const InputDecoration(
                                    labelText: 'Дата выезда',
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _checkOutDate ?? _checkInDate,
                                      firstDate: _checkInDate,
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _checkOutDate = picked);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Итоговая стоимость: ${_calculateTotalPrice()} ₽',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
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



  double _calculateTotalPrice() {
    if (_checkOutDate == null || _checkInDate == null) return 0.0;
    final nights = _checkOutDate!.difference(_checkInDate).inDays;
    // Используем цену из загруженного коттеджа
    return _currentCottage.price * nights;
  }

  Widget _buildImageGallery(List<String> images) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Image.network(
            images[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error);
            },
          );
        },
      ),
    );
  }
}
