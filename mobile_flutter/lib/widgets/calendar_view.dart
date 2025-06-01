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

  void _groupBookingsByDate() {
    _groupedBookings = {};
    for (final booking in widget.bookings) {
      final start = booking.startDate;
      final end = booking.endDate;
      
      for (var date = start; date.isBefore(end); date = date.add(const Duration(days: 1))) {
        if (!_groupedBookings.containsKey(date)) {
          _groupedBookings[date] = [];
        }
        _groupedBookings[date]!.add(booking);
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          TableCalendar<Booking>(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => _selectedDay == day,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) => _groupedBookings[day] ?? [],
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бронирования на ${DateFormat('dd MMMM yyyy').format(_selectedDay!)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...(_groupedBookings[_selectedDay] ?? []).map((booking) =>
                    ListTile(
                      title: Text(
                        '${DateFormat('dd MMMM yyyy').format(booking.startDate)} - '
                        '${DateFormat('dd MMMM yyyy').format(booking.endDate)}',
                      ),
                    )),
                  const SizedBox(height: 16),
                  ...widget.bookings
                      .where((booking) =>
                          _selectedDay!.isAfter(booking.startDate) &&
                          _selectedDay!.isBefore(booking.endDate))
                      .map((booking) => ListTile(
                            leading: const Icon(Icons.person),
                            title: Text('Гостей: ${booking.guests}'),
                            subtitle: Text(
                              'С ${DateFormat('dd MMMM yyyy').format(booking.startDate)} по ${DateFormat('dd MMMM yyyy').format(booking.endDate)}',
                            ),
                          )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
