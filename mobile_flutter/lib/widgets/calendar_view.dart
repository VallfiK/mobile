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
      _clearCaches();
      setState(() {
        _groupedBookings.clear();
        _groupBookings();
      });
    }
  }

  void _groupBookings() {
    final Map<DateTime, List<Booking>> newGroupedBookings = {};
    
    // Сортируем бронирования по дате начала
    final sortedBookings = List<Booking>.from(widget.bookings)
      ..sort((a, b) => a.startDate?.compareTo(b.startDate ?? DateTime.now()) ?? 0);
    
    for (var booking in sortedBookings) {
      if (booking.startDate == null || booking.endDate == null) continue;
      
      // Нормализуем даты (удаляем время)
      final start = DateTime(
        booking.startDate!.year, 
        booking.startDate!.month, 
        booking.startDate!.day
      );
      
      final end = DateTime(
        booking.endDate!.year, 
        booking.endDate!.month, 
        booking.endDate!.day
      );
      
      print('Обработка бронирования: ${booking.id} с $start по $end');
      
      // Добавляем бронирование на все даты в диапазоне
      for (var date = start; !date.isAfter(end); date = date.add(const Duration(days: 1))) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        
        if (!newGroupedBookings.containsKey(normalizedDate)) {
          newGroupedBookings[normalizedDate] = [];
        }
        
        if (!newGroupedBookings[normalizedDate]!.contains(booking)) {
          newGroupedBookings[normalizedDate]!.add(booking);
        }
      }
    }
    
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
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final bookings = widget.bookings.where((booking) {
      if (booking.startDate == null || booking.endDate == null) return false;
      
      // Normalize booking dates to local time
      final startDate = DateTime(
        booking.startDate.year, 
        booking.startDate.month, 
        booking.startDate.day
      );
      
      final endDate = DateTime(
        booking.endDate.year,
        booking.endDate.month,
        booking.endDate.day
      );
      
      // Check if the day is within the booking range (inclusive)
      return (normalizedDay.isAtSameMomentAs(startDate) || 
              normalizedDay.isAfter(startDate)) &&
             (normalizedDay.isAtSameMomentAs(endDate) ||
              normalizedDay.isBefore(endDate));
    }).toList();
    
    return bookings;
  }

  bool _isDateBooked(DateTime day) {
    final bookings = _getBookingsForDay(day);
    return bookings.isNotEmpty;
  }

  Color _getDateColor(DateTime day) {
    final bookings = _getBookingsForDay(day);
    
    if (bookings.isEmpty) return Colors.green;
    
    // Check for any checked-in bookings first (highest priority)
    final checkedInBookings = bookings.where((b) => b.status == 'checked_in').toList();
    if (checkedInBookings.isNotEmpty) {
      return Colors.red;
    }
    
    // Then check for any booked status
    final bookedBookings = bookings.where((b) => b.status == 'booked').toList();
    if (bookedBookings.isNotEmpty) {
      return Colors.yellow;
    }
    
    // If no specific status, check if it's a check-in/check-out day
    final isCheckInDay = _hasCheckIn(day, bookings);
    final isCheckOutDay = _hasCheckOut(day, bookings);
    
    if (isCheckInDay && isCheckOutDay) {
      // If it's both check-in and check-out, prioritize check-in
      return Colors.yellow;
    } else if (isCheckInDay) {
      return Colors.yellow;
    } else if (isCheckOutDay) {
      return Colors.green;
    }
    
    // Default to green if no specific status found
    return Colors.green;
  }

  int _calculateBookingCost(Booking booking) {
    final days = booking.endDate.difference(booking.startDate).inDays;
    return (widget.cottage.price * days).toInt();
  }

  // Проверяем, является ли день днем заезда
  bool _hasCheckIn(DateTime day, List<Booking> bookings) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    
    for (var booking in bookings) {
      if (booking.startDate == null) continue;
      
      // Нормализуем дату заезда (без времени)
      final checkInDate = DateTime(
        booking.startDate.year,
        booking.startDate.month,
        booking.startDate.day,
      );
      
      // Проверяем, является ли день первым днем бронирования
      if (checkInDate.isAtSameMomentAs(normalizedDay)) {
        print('День заезда: $normalizedDay для бронирования ${booking.id}');
        return true;
      }
    }
    
    return false;
  }

  // Проверяем, является ли день днем выезда
  bool _hasCheckOut(DateTime day, List<Booking> bookings) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    
    for (var booking in bookings) {
      if (booking.endDate == null) continue;
      
      // Нормализуем дату выезда (без времени)
      final checkOutDate = DateTime(
        booking.endDate.year,
        booking.endDate.month,
        booking.endDate.day,
      );
      
      // Проверяем, является ли день последним днем бронирования
      if (checkOutDate.isAtSameMomentAs(normalizedDay)) {
        print('День выезда: $normalizedDay для бронирования ${booking.id}');
        return true;
      }
    }
    
    return false;
  }

  // Get the status of bookings for a specific day
  (bool hasCheckIn, bool hasCheckOut, String status) _getDayStatus(DateTime day) {
    final bookings = _getBookingsForDay(day);
    
    if (bookings.isEmpty) {
      return (false, false, 'free');
    }
    
    // Check for any checked-in bookings (highest priority)
    final checkedInBookings = bookings.where((b) => b.status == 'checked_in').toList();
    if (checkedInBookings.isNotEmpty) {
      return (
        _hasCheckIn(day, checkedInBookings),
        _hasCheckOut(day, checkedInBookings),
        'checked_in'
      );
    }
    
    // Then check for any booked status
    final bookedBookings = bookings.where((b) => b.status == 'booked').toList();
    if (bookedBookings.isNotEmpty) {
      return (
        _hasCheckIn(day, bookedBookings),
        _hasCheckOut(day, bookedBookings),
        'booked'
      );
    }
    
    // If no specific status, check for check-in/check-out
    final hasCheckIn = _hasCheckIn(day, bookings);
    final hasCheckOut = _hasCheckOut(day, bookings);
    
    return (
      hasCheckIn,
      hasCheckOut,
      hasCheckIn ? 'booked' : hasCheckOut ? 'free' : 'free'
    );
  }

  // Widget to display a split cell for days with check-in/check-out
  Widget _buildSplitDayCell(DateTime day, bool hasCheckIn, bool hasCheckOut, String status) {
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, _selectedDay);
    
    return Center(
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(2),
            child: CustomPaint(
              painter: SplitDayCellPainter(
                hasCheckIn: hasCheckIn,
                hasCheckOut: hasCheckOut,
                status: status,
                isToday: isToday,
                isSelected: isSelected,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isToday || isSelected ? Colors.blue : Colors.black,
                    fontSize: 14,
                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          if (hasCheckOut)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white, 
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
              ),
            ),
          if (hasCheckIn)
            Positioned(
              left: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status == 'checked_in' ? Colors.red : Colors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white, 
                    width: isSelected ? 1.5 : 1.0,
                  ),
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
                  final (hasCheckIn, hasCheckOut, status) = _getDayStatus(day);
                  final isToday = isSameDay(day, DateTime.now());
                  final isSelected = isSameDay(day, _selectedDay);
                  
                  // Use the split cell for days with check-in/check-out
                  if (hasCheckIn || hasCheckOut) {
                    return _buildSplitDayCell(day, hasCheckIn, hasCheckOut, status);
                  }
                  
                  // For normal days, use a simple circle
                  final color = _getDateColor(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: Colors.blue, width: 2)
                          : isSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isToday || isSelected
                            ? Colors.blue
                            : Colors.black87,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  final (hasCheckIn, hasCheckOut, status) = _getDayStatus(day);
                  final isSelected = isSameDay(day, _selectedDay);
                  
                  // Use the split cell for days with check-in/check-out
                  if (hasCheckIn || hasCheckOut) {
                    return _buildSplitDayCell(day, hasCheckIn, hasCheckOut, status);
                  }
                  
                  // For today, show a special style
                  final color = _getDateColor(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  final (hasCheckIn, hasCheckOut, status) = _getDayStatus(day);
                  
                  // Use the split cell for days with check-in/check-out
                  if (hasCheckIn || hasCheckOut) {
                    return _buildSplitDayCell(day, hasCheckIn, hasCheckOut, status);
                  }
                  
                  // For selected day, show a special style
                  final color = _getDateColor(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        color: Colors.blue,
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
                                          selectedDate: _selectedDay!,
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
                            // Для даты выезда показываем чип только если это последний день бронирования
                            final isCheckOutDay = _selectedDay!.isAtSameMomentAs(DateTime(
                              booking.endDate.year,
                              booking.endDate.month,
                              booking.endDate.day,
                            ));
                            
                            // Для даты заезда показываем чип только если это первый день бронирования
                            final isCheckInDay = _selectedDay!.isAtSameMomentAs(DateTime(
                              booking.startDate.year,
                              booking.startDate.month,
                              booking.startDate.day,
                            ));

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
                                        if (booking.startDate != null && booking.endDate != null)
                                          Builder(
                                            builder: (context) {
                                              final startDate = booking.startDate!;
                                              final endDate = booking.endDate!;
                                              
                                              return Text(
                                                'С ${DateFormat('dd.MM.yyyy').format(startDate)} по ${DateFormat('dd.MM.yyyy').format(endDate)}',
                                                style: const TextStyle(fontSize: 13),
                                              );
                                            },
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

// Custom painter for split calendar cells
class SplitDayCellPainter extends CustomPainter {
  final bool hasCheckIn;
  final bool hasCheckOut;
  final String status;
  final bool isToday;
  final bool isSelected;

  SplitDayCellPainter({
    required this.hasCheckIn,
    required this.hasCheckOut,
    required this.status,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double radius = size.width / 2;
    final center = Offset(radius, radius);

    // Draw the base circle
    if (isSelected) {
      paint.color = Colors.blue.withOpacity(0.1);
      canvas.drawCircle(center, radius, paint);
    } else if (isToday) {
      paint.color = Colors.blue.withOpacity(0.05);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw the split cell if needed
    if (hasCheckIn && hasCheckOut) {
      // Draw the check-out (free) half
      paint.color = Colors.green.withOpacity(0.3);
      
      // Draw a semi-circle for check-out
      final checkOutPath = Path()
        ..moveTo(radius, 0)
        ..lineTo(radius, radius * 2)
        ..lineTo(0, radius * 2)
        ..arcToPoint(
          Offset(0, 0),
          radius: Radius.circular(radius),
          clockwise: false,
        )
        ..close();
      
      canvas.drawPath(checkOutPath, paint);
      
      // Draw the check-in half with status color
      paint.color = _getStatusColor(status).withOpacity(0.3);
      
      // Draw a semi-circle for check-in
      final checkInPath = Path()
        ..moveTo(radius, 0)
        ..lineTo(radius * 2, 0)
        ..lineTo(radius * 2, radius * 2)
        ..lineTo(radius, radius * 2)
        ..close();
      
      canvas.drawPath(checkInPath, paint);
    } else if (hasCheckIn) {
      // Only check-in
      paint.color = _getStatusColor(status).withOpacity(0.3);
      canvas.drawCircle(center, radius, paint);
    } else if (hasCheckOut) {
      // Only check-out
      paint.color = Colors.green.withOpacity(0.3);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw the border
    final borderPaint = Paint()
      ..color = isSelected 
          ? Colors.blue 
          : isToday 
              ? Colors.blue.withOpacity(0.7) 
              : Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.0;
    
    canvas.drawCircle(center, radius - borderPaint.strokeWidth / 2, borderPaint);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'checked_in':
        return Colors.red;
      case 'booked':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  @override
  bool shouldRepaint(covariant SplitDayCellPainter oldDelegate) {
    return hasCheckIn != oldDelegate.hasCheckIn ||
           hasCheckOut != oldDelegate.hasCheckOut ||
           status != oldDelegate.status ||
           isToday != oldDelegate.isToday ||
           isSelected != oldDelegate.isSelected;
  }
}