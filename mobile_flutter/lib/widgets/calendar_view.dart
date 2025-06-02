import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/booking.dart';
import '../models/cottage.dart';
import 'booking_cancellation_dialog.dart';
import 'package:intl/intl.dart';

class CalendarView extends StatefulWidget {
  final Cottage cottage;
  final List<Booking> bookings;
  final Function(String) onCancelBooking;

  const CalendarView({
    super.key,
    required this.cottage,
    required this.bookings,
    required this.onCancelBooking,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Booking>> _groupedBookings = {};

  @override
  void initState() {
    super.initState();
    _groupBookingsByDate();
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookings != widget.bookings) {
      _groupBookingsByDate();
    }
  }

  void _groupBookingsByDate() {
    _groupedBookings = {};
    for (final booking in widget.bookings) {
      final start = booking.startDate;
      final end = booking.endDate;
      
      for (var date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        if (!_groupedBookings.containsKey(normalizedDate)) {
          _groupedBookings[normalizedDate] = [];
        }
        _groupedBookings[normalizedDate]!.add(booking);
      }
    }
  }

  Future<void> _showCancellationDialog(Booking booking) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BookingCancellationDialog(
        booking: booking,
        onConfirm: () {
          Navigator.of(context).pop(true);
          widget.onCancelBooking(booking.id);
        },
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  List<Booking> _getBookingsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _groupedBookings[normalizedDay] ?? [];
  }

  bool _isDateBooked(DateTime day) {
    final bookings = _getBookingsForDay(day);
    return bookings.isNotEmpty;
  }

  Color _getDateColor(DateTime day) {
    final bookings = _getBookingsForDay(day);
    if (bookings.isEmpty) return Colors.green;
    
    // Проверяем статусы бронирований
    if (bookings.any((b) => b.status == 'occupied')) {
      return Colors.red;
    } else if (bookings.any((b) => b.status == 'booked')) {
      return Colors.yellow;
    }
    
    return Colors.green;
  }

  int _calculateBookingCost(Booking booking) {
    final days = booking.endDate.difference(booking.startDate).inDays;
    return (widget.cottage.price * days).toInt();
  }

  @override
  Widget build(BuildContext context) {
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
          TableCalendar<Booking>(
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            eventLoader: _getBookingsForDay,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                final color = _getDateColor(date);
                
                return Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                if (_isDateBooked(day)) {
                  final color = _getDateColor(day);
                  return Center(
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: color == Colors.red ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          if (_selectedDay != null)
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
                  if (_getBookingsForDay(_selectedDay!).isNotEmpty)
                    ..._getBookingsForDay(_selectedDay!).map((booking) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: booking.status == 'booked'
                              ? Colors.yellow
                              : booking.status == 'occupied'
                                  ? Colors.red
                                  : Colors.green,
                          child: Text(booking.guestName.isNotEmpty ? booking.guestName[0] : '?'),
                        ),
                        title: Text(booking.guestName.isNotEmpty ? booking.guestName : 'Гость'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'С ${DateFormat('dd.MM').format(booking.startDate)} по ${DateFormat('dd.MM').format(booking.endDate)}',
                            ),
                            Text(
                              'Стоимость: ${_calculateBookingCost(booking)} руб.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (booking.phone.isNotEmpty)
                              Text(
                                booking.phone,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            if (booking.email.isNotEmpty)
                              Text(
                                booking.email,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        trailing: booking.status == 'booked'
                            ? IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _showCancellationDialog(booking),
                              )
                            : null,
                      ),
                    )).toList()
                  else
                    const Text('Нет бронирований на эту дату'),
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
                    const Text('Занято'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}