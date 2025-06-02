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
            eventLoader: (day) {
              final bookingsForDay = _groupedBookings[day] ?? [];
              return bookingsForDay.map((booking) => booking).toList();
            },
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(4),
              cellPadding: const EdgeInsets.all(6),
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.blue),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                final booking = events.first;
                
                // Определяем цвет в зависимости от статуса бронирования
                Color color;
                if (booking.status == 'booked') {
                  color = Colors.yellow;
                } else if (booking.status == 'occupied') {
                  color = Colors.red;
                } else {
                  color = Colors.green;
                }
                
                return Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
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
                    'Bookings on ${DateFormat('dd MMMM yyyy').format(_selectedDay!)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ..._groupedBookings[_selectedDay]!
                      .map((booking) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: booking.status == 'booked'
                                    ? Colors.yellow
                                    : booking.status == 'occupied'
                                        ? Colors.red
                                        : Colors.green,
                                child: Text(booking.guestName[0]),
                              ),
                              title: Text(booking.guestName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cost: ${booking.totalCost.toStringAsFixed(2)} rub',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  if (booking.guestPhone.isNotEmpty)
                                    Text(
                                      booking.guestPhone,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  if (booking.guestEmail.isNotEmpty)
                                    Text(
                                      booking.guestEmail,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  if (booking.notes.isNotEmpty)
                                    Text(
                                      booking.notes,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              trailing: booking.status == 'booked'
                                  ? IconButton(
                                      icon: const Icon(Icons.cancel),
                                      onPressed: () => _showCancellationDialog(booking),
                                    )
                                  : null,
                            ),
                          ))
                      .toList(),
                  const SizedBox(height: 8),
                  Text(
                    'Colors:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.yellow),
                      SizedBox(width: 4),
                      Text(
                        'Yellow - Booked',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text(
                        'Red - Occupied',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Green - Available',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
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
