import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../models/booking.dart';
import '../services/cottage_service.dart';
import '../services/booking_service.dart';
import '../widgets/calendar_view.dart';
import '../widgets/booking_filters.dart';
import '../widgets/booking_form_dialog.dart';

class CottageDetailScreen extends StatefulWidget {
  final String cottageId;

  const CottageDetailScreen({super.key, required this.cottageId});

  @override
  State<CottageDetailScreen> createState() => _CottageDetailScreenState();
}

class _CottageDetailScreenState extends State<CottageDetailScreen> {
  late Future<Cottage> _cottageFuture;
  late Future<List<Booking>> _bookingsFuture;
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

  Future<void> _cancelBooking(String bookingId) async {
    setState(() => _isLoading = true);
    try {
      final bookingService = Provider.of<BookingService>(context, listen: false);
      await bookingService.cancelBooking(bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно отменено!')),
      );

      // Обновляем данные после отмены
      await _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Обновление данных о коттедже и бронированиях
  Future<void> _refreshData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Обновляем данные о коттедже
      _cottageFuture = Provider.of<CottageService>(context, listen: false)
          .getCottage(widget.cottageId);
      
      // Обновляем данные о бронированиях
      final newBookings = await Provider.of<BookingService>(context, listen: false)
          .getBookingsByCottage(widget.cottageId);
      
      if (mounted) {
        setState(() {
          _bookingsFuture = Future.value(newBookings);
          _filteredBookings = List.from(newBookings);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные обновлены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createBooking(Booking booking) async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<BookingService>(context, listen: false)
          .createBooking(booking);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно создано!')),
      );

      setState(() {
        _bookingsFuture = Provider.of<BookingService>(context, listen: false)
            .getBookingsByCottage(widget.cottageId);
        _filteredBookings = [];
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

  void _showBookingDialog(BuildContext context, Cottage cottage, DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (context) => BookingFormDialog(
        cottage: cottage,
        selectedDate: selectedDate,
        onSubmit: (booking) async {
          await _createBooking(booking);
          // Обновляем список бронирований
          setState(() {
            _bookingsFuture = Provider.of<BookingService>(context, listen: false)
                .getBookingsByCottage(widget.cottageId);
            _filteredBookings = [];
          });
        },
        bookingService: Provider.of<BookingService>(context, listen: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Cottage>(
          future: _cottageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return const Text('Ошибка загрузки');
              }
              return Text(snapshot.data?.name ?? 'Загрузка...');
            }
            return const Text('Загрузка...');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Обновить данные',
          ),
        ],
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
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 32.0
                  ),
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
                            Text(
                              'Календарь бронирований',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            CalendarView(
                              key: ValueKey(_filteredBookings.length), // Принудительное обновление при изменении бронирований
                              cottage: cottage,
                              bookings: _filteredBookings,
                              onCancelBooking: (bookingId) async {
                                await _cancelBooking(bookingId);
                                // После отмены обновляем данные
                                await _refreshData();
                              },
                              onDateSelected: (selectedDate) async {
                                try {
                                  final normalizedDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                  );
                                  
                                  final newBookings = await Provider.of<BookingService>(context, listen: false)
                                      .getBookingsByDate(widget.cottageId, normalizedDate);
                                  
                                  if (mounted) {
                                    setState(() {
                                      // Создаем множество существующих ID бронирований
                                      final existingIds = Set<String>.from(
                                        _filteredBookings.map((b) => b.id)
                                      );
                                      
                                      // Добавляем только новые бронирования
                                      for (var booking in newBookings) {
                                        if (!existingIds.contains(booking.id)) {
                                          _filteredBookings.add(booking);
                                        }
                                      }
                                    });
                                  }
                                  
                                  // Проверяем, есть ли бронирование на выбранную дату во ВСЕХ бронированиях
                                  final hasBookings = _filteredBookings.any((booking) {
                                    if (booking.startDate == null || booking.endDate == null) return false;
                                    
                                    final start = DateTime(
                                      booking.startDate.year,
                                      booking.startDate.month,
                                      booking.startDate.day,
                                    );
                                    final end = DateTime(
                                      booking.endDate.year,
                                      booking.endDate.month,
                                      booking.endDate.day,
                                    );
                                    
                                    // Проверяем, входит ли выбранная дата в диапазон бронирования
                                    return !normalizedDate.isBefore(start) && 
                                           !normalizedDate.isAfter(end);
                                  });
                                  
                                  print('Selected date: $normalizedDate');
                                  print('Has bookings: $hasBookings');
                                  print('Total bookings: ${_filteredBookings.length}');
                                  
                                  // Если нет бронирований, показываем форму бронирования
                                  if (!hasBookings) {
                                    _showBookingDialog(context, cottage, normalizedDate);
                                  }
                                  
                                  return _filteredBookings;
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка загрузки бронирований: $e')),
                                  );
                                  return _filteredBookings;
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64),
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
                  child: Icon(Icons.error_outline, size: 64),
                ),
              );
            },
          );
        },
      ),
    );
  }
}