import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/booking.dart';
import '../models/cottage.dart';
import '../utils/date_extensions.dart';
import 'booking_cancellation_dialog.dart';
import 'booking_dialog.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import '../services/booking_service.dart';
import 'dart:async';

class CalendarView extends StatefulWidget {
  final Cottage cottage;
  final List<Booking> bookings;
  final Function(String) onCancelBooking;
  final Future<List<Booking>> Function(DateTime)? onDateSelected;

  const CalendarView({
    super.key,
    required this.cottage,
    required this.bookings,
    required this.onCancelBooking,
    this.onDateSelected,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Booking>> _groupedBookings = {};
  bool _localeInitialized = false;
  bool _isLoading = false;
  Timer? _debounceTimer;
  final _bookingCache = <String, List<Booking>>{};
  final _dateAvailabilityCache = <String, bool>{};

  // Добавляем время заезда и выезда как константы
  static const checkOutTime = TimeOfDay(hour: 12, minute: 0);
  static const checkInTime = TimeOfDay(hour: 14, minute: 0);

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _groupBookings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _clearCaches();
    super.dispose();
  }

  void _clearCaches() {
    _bookingCache.clear();
    _dateAvailabilityCache.clear();
  }

  String _getCacheKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  Future<void> _initializeLocale() async {
    if (!_localeInitialized) {
      await initializeDateFormatting('ru_RU', null);
      if (mounted) {
        setState(() {
          _localeInitialized = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookings != oldWidget.bookings || 
        widget.cottage.id != oldWidget.cottage.id) {
      setState(() {
        _groupedBookings.clear();
        _groupBookings();
      });
    }
  }

  void _groupBookings() {
    print('DEBUG: _groupBookings called. Total bookings: ${widget.bookings.length}');
    final newGroupedBookings = <DateTime, List<Booking>>{};
    
    // Выводим все бронирования для отладки
    for (var booking in widget.bookings) {
      print('DEBUG: Available booking: ID=${booking.id}, status=${booking.status}, startDate=${booking.startDate}, endDate=${booking.endDate}');
    }
    
    for (var booking in widget.bookings) {
      print('DEBUG: Processing booking ID: ${booking.id}, status: ${booking.status}');
      print('DEBUG: Original dates - startDate: ${booking.startDate}, endDate: ${booking.endDate}');
      
      // Пропускаем отмененные бронирования
      if (booking.status == 'cancelled') {
        print('DEBUG: Skipping cancelled booking: ${booking.id}');
        continue;
      }
      
      // Нормализуем даты для правильного отображения в календаре
      // Используем только дату без времени для определения диапазона дней
      final startDay = DateTime(booking.startDate.year, booking.startDate.month, booking.startDate.day);
      final endDay = DateTime(booking.endDate.year, booking.endDate.month, booking.endDate.day);
      
      print('DEBUG: Normalized date range - startDay: $startDay, endDay: $endDay');
      
      // Добавляем бронирование на все даты в диапазоне
      var currentDate = startDay;
      
      // Проверяем, что диапазон дат корректный
      if (endDay.isBefore(startDay)) {
        print('DEBUG: WARNING! End date is before start date: $endDay < $startDay');
        // Если даты перепутаны, все равно добавляем хотя бы на день заезда
        if (!newGroupedBookings.containsKey(startDay)) {
          newGroupedBookings[startDay] = [];
        }
        if (!newGroupedBookings[startDay]!.any((b) => b.id == booking.id)) {
          newGroupedBookings[startDay]!.add(booking);
          print('DEBUG: Added booking ${booking.id} to date $startDay (single day due to invalid range)');
        }
        continue;
      }
      
      print('DEBUG: Adding booking to date range: $currentDate to $endDay (inclusive)');
      
      // Добавляем каждый день в диапазоне бронирования (включая день выезда)
      while (!currentDate.isAfter(endDay)) {
        if (!newGroupedBookings.containsKey(currentDate)) {
          newGroupedBookings[currentDate] = [];
        }
        
        if (!newGroupedBookings[currentDate]!.any((b) => b.id == booking.id)) {
          newGroupedBookings[currentDate]!.add(booking);
          print('DEBUG: Added booking ${booking.id} to date $currentDate');
        }
        
        // Переходим к следующему дню
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
    
    print('DEBUG: Final grouped bookings by date:');
    newGroupedBookings.forEach((date, bookings) {
      print('DEBUG: Date: $date, Bookings: ${bookings.length}, IDs: ${bookings.map((b) => b.id).join(', ')}');
    });
    
    setState(() {
      _groupedBookings = newGroupedBookings;
    });
  }

  Future<void> _showCancellationDialog(Booking booking) async {
    if (booking.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: ID бронирования отсутствует')),
      );
      return;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BookingCancellationDialog(
        booking: booking,
        onConfirm: () {
          Navigator.of(context).pop(true);
          print('Cancelling booking with ID: ${booking.id}');
          widget.onCancelBooking(booking.id);
        },
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  List<Booking> _getBookingsForDay(DateTime day) {
    // Нормализуем день до полночи
    final normalizedDay = DateTime(day.year, day.month, day.day);
    
    print('DEBUG: _getBookingsForDay called for day: $normalizedDay');
    print('DEBUG: Total bookings to check: ${widget.bookings.length}');
    
    // Используем кэш сгруппированных бронирований, если он доступен
    if (_groupedBookings != null && _groupedBookings!.containsKey(normalizedDay)) {
      print('DEBUG: Using cached bookings for day: $normalizedDay, count: ${_groupedBookings![normalizedDay]!.length}');
      return _groupedBookings![normalizedDay]!;
    }
    
    // Если кэш недоступен, фильтруем бронирования вручную
    print('DEBUG: Cache miss for day: $normalizedDay, filtering manually');
    final result = <Booking>[];
    
    for (var booking in widget.bookings) {
      if (booking.status == 'cancelled') {
        print('DEBUG: Skipping cancelled booking: ${booking.id}');
        continue;
      }
      
      print('DEBUG: Checking booking ID: ${booking.id}, startDate: ${booking.startDate}, endDate: ${booking.endDate}');
      
      // Нормализуем даты бронирования (только дата, без времени)
      final bookingStartDay = DateTime(booking.startDate.year, booking.startDate.month, booking.startDate.day);
      final bookingEndDay = DateTime(booking.endDate.year, booking.endDate.month, booking.endDate.day);
      
      print('DEBUG: Normalized booking dates - startDay: $bookingStartDay, endDay: $bookingEndDay');
      
      // Проверяем корректность диапазона дат
      if (bookingEndDay.isBefore(bookingStartDay)) {
        print('DEBUG: WARNING! Invalid date range for booking ${booking.id}: end date is before start date');
        // Даже если даты перепутаны, добавляем бронирование на день заезда
        if (normalizedDay.isAtSameMomentAs(bookingStartDay)) {
          print('DEBUG: Adding booking with invalid range to start day $normalizedDay');
          result.add(booking);
        }
        continue;
      }
      
      // Проверяем, входит ли день в диапазон бронирования (включая дни заезда и выезда)
      if (normalizedDay.isAtSameMomentAs(bookingStartDay) || 
          normalizedDay.isAtSameMomentAs(bookingEndDay) || 
          (normalizedDay.isAfter(bookingStartDay) && normalizedDay.isBefore(bookingEndDay))) {
        print('DEBUG: Day $normalizedDay is within booking range, adding booking ${booking.id}');
        result.add(booking);
      } else {
        print('DEBUG: Day $normalizedDay is NOT within booking range for booking ${booking.id}');
      }
    }
    
    print('DEBUG: Found ${result.length} bookings for day: $normalizedDay');
    if (result.isNotEmpty) {
      print('DEBUG: Booking IDs for day $normalizedDay: ${result.map((b) => b.id).join(', ')}');
    }
    
    return result;
  }

  bool _isDateBooked(DateTime day) {
    final bookings = _getBookingsForDay(day);
    return bookings.isNotEmpty;
  }

  Color _getDateColor(DateTime day) {
    final bookings = _getBookingsForDay(day);
    
    if (bookings.isEmpty) return Colors.green;
    
    // Получаем информацию о заезде/выезде и статусе
    final (hasCheckIn, hasCheckOut, status) = _getDayStatus(day);
    
    // Если есть и заезд, и выезд, используем специальный виджет
    if (hasCheckIn || hasCheckOut) {
      // Цвет будет определен в SplitDayCellPainter
      return Colors.transparent;
    }
    
    // Приоритет: checked_in > booked > checked_out > free
    switch (status) {
      case 'checked_in':
        return Colors.red;
      case 'booked':
        return Colors.yellow;
      case 'checked_out':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }



  int _calculateBookingCost(Booking booking) {
    final days = booking.endDate.difference(booking.startDate).inDays;
    return (widget.cottage.price * days).toInt();
  }

  // Проверяем, есть ли заезд в этот день
  bool _hasCheckIn(DateTime day, List<Booking> bookings) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return bookings.any((booking) {
      final bookingStartDay = DateTime(
        booking.startDate.year, 
        booking.startDate.month, 
        booking.startDate.day,
      );
      return normalizedDay.isAtSameMomentAs(bookingStartDay);
    });
  }

  // Проверяем, есть ли выезд в этот день
  bool _hasCheckOut(DateTime day, List<Booking> bookings) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return bookings.any((booking) {
      final bookingEndDay = DateTime(
        booking.endDate.year, 
        booking.endDate.month, 
        booking.endDate.day,
      );
      return normalizedDay.isAtSameMomentAs(bookingEndDay);
    });
  }

  // Получаем статус бронирований на день
  (bool, bool, String) _getDayStatus(DateTime day) {
    final bookings = _getBookingsForDay(day);
    final hasCheckIn = _hasCheckIn(day, bookings);
    final hasCheckOut = _hasCheckOut(day, bookings);
    
    // Определяем статус дня
    String status = 'free';
    if (bookings.isEmpty) {
      status = 'free';
    } else if (bookings.any((b) => b.status == 'checked_in')) {
      status = 'checked_in';
    } else if (bookings.any((b) => b.status == 'booked')) {
      status = 'booked';
    }
    
    return (hasCheckIn, hasCheckOut, status);
  }

  // Виджет для отображения разделенной ячейки
  Widget _buildSplitDayCell(DateTime day, bool hasCheckIn, bool hasCheckOut, String status) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 35,
            height: 35,
            child: CustomPaint(
              painter: SplitDayCellPainter(
                hasCheckIn: hasCheckIn,
                hasCheckOut: hasCheckOut,
                status: status,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Показываем индикатор выезда
          if (hasCheckOut)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          // Показываем индикатор заезда
          if (hasCheckIn)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status == 'checked_in' ? Colors.red : Colors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Оптимизированная проверка доступности даты с кэшированием
  Future<bool> _checkDateAvailability(DateTime date) async {
    if (_isLoading) return false;
    
    final cacheKey = _getCacheKey(date);
    if (_dateAvailabilityCache.containsKey(cacheKey)) {
      return _dateAvailabilityCache[cacheKey]!;
    }
    
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final bookings = _getBookingsForDay(normalizedDate);
    
    // Проверяем бронирования на этот день
    bool hasConflict = false;
    for (var booking in bookings) {
      // Если это дата выезда (check-out)
      if (booking.endDate.year == date.year &&
          booking.endDate.month == date.month &&
          booking.endDate.day == date.day) {
        // Проверяем, нет ли других заездов до 14:00
        final otherBookings = bookings.where((b) => 
          b.id != booking.id &&
          b.startDate.year == date.year &&
          b.startDate.month == date.month &&
          b.startDate.day == date.day
        );
        
        if (otherBookings.isEmpty) {
          // Если других заездов нет, дата доступна для бронирования
          _dateAvailabilityCache[cacheKey] = true;
          return true;
        }
      }
      
      // Если это не дата выезда или есть конфликтующие бронирования
      hasConflict = true;
    }
    
    if (!hasConflict) {
      _dateAvailabilityCache[cacheKey] = true;
      return true;
    }
    
    // В остальных случаях проверяем через API
    try {
      _isLoading = true;
      final response = await widget.onDateSelected?.call(normalizedDate);
      final isAvailable = response?.isEmpty ?? false;
      _dateAvailabilityCache[cacheKey] = isAvailable;
      return isAvailable;
    } finally {
      _isLoading = false;
    }
  }

  void _handleDateSelection(DateTime selectedDate) {
    // Отменяем предыдущий таймер, если он есть
    _debounceTimer?.cancel();
    
    // Создаем новый таймер с меньшей задержкой
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      
      final isAvailable = await _checkDateAvailability(selectedDate);
      if (!mounted) return;
      
      if (isAvailable) {
        widget.onDateSelected?.call(selectedDate);
      } else {
        // Проверяем, есть ли выезд в этот день
        final bookings = _getBookingsForDay(selectedDate);
        final hasCheckOut = bookings.any((booking) =>
          booking.endDate.year == selectedDate.year &&
          booking.endDate.month == selectedDate.month &&
          booking.endDate.day == selectedDate.day
        );

        // Показываем соответствующее сообщение
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasCheckOut
                ? 'В этот день есть выезд в 12:00 и возможен заезд в 14:00'
                : 'Выбранная дата недоступна для бронирования'
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    try {
      final selectedDayBookings = _selectedDay != null ? _getBookingsForDay(_selectedDay!) : [];
      print('Building calendar view. Selected day: $_selectedDay');
      print('Bookings for selected day: ${selectedDayBookings.length}');

      return Card(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Календарь бронирований',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              locale: 'ru_RU',
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _handleDateSelection(selectedDay);
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  // Получаем информацию о заезде/выезде и статусе дня
                  final (hasCheckIn, hasCheckOut, status) = _getDayStatus(day);
                  
                  // Если есть заезд или выезд, используем специальный виджет
                  if (hasCheckIn || hasCheckOut) {
                    return _buildSplitDayCell(day, hasCheckIn, hasCheckOut, status);
                  }
                  
                  // Для обычных дней используем стандартный вид
                  final color = _getDateColor(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              calendarStyle: const CalendarStyle(
                isTodayHighlighted: false,
                outsideDaysVisible: false,
                markersAlignment: Alignment.bottomCenter,
                markerMargin: EdgeInsets.zero,
                markersMaxCount: 1,
                cellMargin: EdgeInsets.zero,
              ),
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            if (_selectedDay != null && _selectedDay != DateTime(0))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Бронирования на ${DateFormat('dd MMMM yyyy', 'ru').format(_selectedDay!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    
                    if (selectedDayBookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('На выбранную дату бронирований нет'),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: selectedDayBookings.length + 1, // +1 для кнопки добавления
                          itemBuilder: (context, index) {
                            // Если это последний элемент, проверяем возможность добавления нового заезда
                            if (index == selectedDayBookings.length) {
                              // Проверяем, есть ли выезд в этот день
                              bool hasCheckOut = selectedDayBookings.any((booking) =>
                                booking.endDate.year == _selectedDay!.year &&
                                booking.endDate.month == _selectedDay!.month &&
                                booking.endDate.day == _selectedDay!.day
                              );

                              if (hasCheckOut) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Добавить заезд на 14:00'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      // Используем существующий диалог бронирования
                                      showDialog(
                                        context: context,
                                        builder: (context) => BookingDialog(
                                          cottageId: widget.cottage.id,
                                          initialDate: _selectedDay!,
                                          onBookingCreated: (booking) {
                                            setState(() {
                                              _groupBookings();
                                            });
                                          },
                                          bookingService: Provider.of<BookingService>(context, listen: false),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            final booking = selectedDayBookings[index];
                            final isCheckOutDay = booking.endDate.year == _selectedDay!.year &&
                                                booking.endDate.month == _selectedDay!.month &&
                                                booking.endDate.day == _selectedDay!.day;
                            final isCheckInDay = booking.startDate.year == _selectedDay!.year &&
                                               booking.startDate.month == _selectedDay!.month &&
                                               booking.startDate.day == _selectedDay!.day;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: booking.status == 'booked'
                                          ? Colors.yellow
                                          : booking.status == 'checked_in'
                                              ? Colors.red
                                              : Colors.green,
                                      child: Text(
                                        (booking.guestName?.isNotEmpty ?? false) 
                                            ? booking.guestName![0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: booking.status == 'booked' 
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(booking.guestName ?? 'Гость'),
                                        const SizedBox(width: 8),
                                        if (isCheckInDay)
                                          Chip(
                                            label: const Text('Заезд 14:00'),
                                            backgroundColor: Colors.green.withOpacity(0.2),
                                          ),
                                        if (isCheckOutDay)
                                          Chip(
                                            label: const Text('Выезд 12:00'),
                                            backgroundColor: Colors.orange.withOpacity(0.2),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Статус: ${booking.status == 'booked' ? 'Забронировано' : booking.status == 'checked_in' ? 'Заселено' : booking.status == 'checked_out' ? 'Выселено' : 'Свободно'}',
                                          style: TextStyle(
                                            color: booking.status == 'booked' 
                                                ? Colors.orange
                                                : booking.status == 'checked_in'
                                                    ? Colors.red
                                                    : Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'С ${DateFormat('dd.MM.yyyy HH:mm').format(booking.startDate)} по ${DateFormat('dd.MM.yyyy HH:mm').format(booking.endDate)}',
                                        ),
                                        Text(
                                          'Количество гостей: ${booking.guests}',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        if (booking.totalCost > 0)
                                          Text(
                                            'Стоимость: ${booking.totalCost.toStringAsFixed(2)} руб.',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        if (booking.notes.isNotEmpty)
                                          Text(
                                            'Примечания: ${booking.notes}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        if (booking.phone.isNotEmpty)
                                          Text(
                                            'Телефон: ${booking.phone}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        if (booking.email.isNotEmpty)
                                          Text(
                                            'Email: ${booking.email}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (booking.status != 'cancelled')
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (booking.status == 'booked')
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.login),
                                              label: const Text('Заселить'),
                                              onPressed: () async {
                                                try {
                                                  await Provider.of<BookingService>(context, listen: false)
                                                      .updateBookingStatus(booking.id, 'checked_in');
                                                  
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Гость успешно заселен')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Ошибка: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          if (booking.status == 'checked_in')
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.logout),
                                              label: const Text('Выселить'),
                                              onPressed: () async {
                                                try {
                                                  await Provider.of<BookingService>(context, listen: false)
                                                      .updateBookingStatus(booking.id, 'checked_out');
                                                  
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Гость успешно выселен')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Ошибка: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          if (booking.status == 'booked')
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.cancel),
                                              label: const Text('Отменить'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => _showCancellationDialog(booking),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Легенда:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Свободно'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Забронировано'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Заселено'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Ошибка при построении календаря: $e');
      debugPrint('Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Ошибка при построении календаря: $e'),
            TextButton(
              onPressed: () {
                setState(() {
                  _groupBookings();
                });
              },
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }
  }
}

// Добавляем новый класс для отрисовки разделенной ячейки
class SplitDayCellPainter extends CustomPainter {
  final bool hasCheckIn;
  final bool hasCheckOut;
  final String status;

  SplitDayCellPainter({
    required this.hasCheckIn,
    required this.hasCheckOut,
    required this.status,
  });

  Color getStatusColor(String status) {
    switch (status) {
      case 'checked_in':
        return Colors.red;
      case 'booked':
        return Colors.yellow;
      case 'checked_out':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    final double radius = size.width / 2;

    if (hasCheckIn && hasCheckOut) {
      // День и заезда, и выезда - рисуем диагональное разделение
      
      // Заполняем нижнюю половину (выезд)
      paint.color = Colors.green.withOpacity(0.4);
      final checkOutPath = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(checkOutPath, paint);
      
      // Заполняем верхнюю половину (заезд)
      paint.color = getStatusColor(status).withOpacity(0.4);
      final checkInPath = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(checkInPath, paint);
      
      // Рисуем диагональную линию разделения
      final dividerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, 0),
        dividerPaint
      );
      
    } else if (hasCheckOut) {
      // Только выезд
      paint.color = Colors.green.withOpacity(0.3);
      canvas.drawCircle(Offset(radius, radius), radius, paint);
      
      // Добавляем стрелку выезда
      final arrowPaint = Paint()
        ..color = Colors.green.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Рисуем стрелку вправо
      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.5),
        Offset(size.width * 0.7, size.height * 0.5),
        arrowPaint
      );
      
      // Наконечник стрелки
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.5),
        Offset(size.width * 0.6, size.height * 0.4),
        arrowPaint
      );
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.5),
        Offset(size.width * 0.6, size.height * 0.6),
        arrowPaint
      );
      
    } else if (hasCheckIn) {
      // Только заезд
      paint.color = getStatusColor(status).withOpacity(0.3);
      canvas.drawCircle(Offset(radius, radius), radius, paint);
      
      // Добавляем стрелку заезда
      final arrowPaint = Paint()
        ..color = status == 'checked_in' ? Colors.red.shade700 : Colors.yellow.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Рисуем стрелку влево
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.5),
        Offset(size.width * 0.3, size.height * 0.5),
        arrowPaint
      );
      
      // Наконечник стрелки
      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.5),
        Offset(size.width * 0.4, size.height * 0.4),
        arrowPaint
      );
      canvas.drawLine(
        Offset(size.width * 0.3, size.height * 0.5),
        Offset(size.width * 0.4, size.height * 0.6),
        arrowPaint
      );
    } else {
      // Обычный день без заезда/выезда
      paint.color = Colors.green.withOpacity(0.2);
      canvas.drawCircle(Offset(radius, radius), radius, paint);
    }

    // Рисуем границу ячейки
    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is SplitDayCellPainter) {
      return oldDelegate.hasCheckIn != hasCheckIn ||
             oldDelegate.hasCheckOut != hasCheckOut ||
             oldDelegate.status != status;
    }
    return true;
  }
}