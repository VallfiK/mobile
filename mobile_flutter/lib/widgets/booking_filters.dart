import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

class BookingFilters extends StatefulWidget {
  final Function(List<Booking>) onFilterApplied;
  final List<Booking> bookings;

  const BookingFilters({
    super.key,
    required this.onFilterApplied,
    required this.bookings,
  });

  @override
  State<BookingFilters> createState() => _BookingFiltersState();
}

class _BookingFiltersState extends State<BookingFilters> {
  DateTime? _startDate;
  DateTime? _endDate;
  int? _minGuests;
  int? _maxGuests;

  void _applyFilters() {
    List<Booking> filteredBookings = widget.bookings;

    if (_startDate != null) {
      filteredBookings = filteredBookings.where((booking) =>
          booking.endDate.isAfter(_startDate!)).toList();
    }

    if (_endDate != null) {
      filteredBookings = filteredBookings.where((booking) =>
          booking.startDate.isBefore(_endDate!)).toList();
    }

    if (_minGuests != null) {
      filteredBookings = filteredBookings
          .where((booking) => booking.guests >= _minGuests!)
          .toList();
    }

    if (_maxGuests != null) {
      filteredBookings = filteredBookings
          .where((booking) => booking.guests <= _maxGuests!)
          .toList();
    }

    widget.onFilterApplied(filteredBookings);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate != null
                          ? DateFormat('dd MMMM yyyy').format(_startDate!)
                          : 'Дата заезда',
                    ),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );

                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate != null && _endDate!.isBefore(picked)) {
                            _endDate = picked.add(const Duration(days: 1));
                          }
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _endDate != null
                          ? DateFormat('dd MMMM yyyy').format(_endDate!)
                          : 'Дата выезда',
                    ),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ??
                            (_startDate != null
                                ? _startDate!.add(const Duration(days: 1))
                                : DateTime.now()),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );

                      if (picked != null) {
                        setState(() => _endDate = picked);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Минимальное количество гостей',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final guests = int.tryParse(value);
                      if (guests != null && guests > 0) {
                        setState(() => _minGuests = guests);
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Максимальное количество гостей',
                      prefixIcon: Icon(Icons.people),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final guests = int.tryParse(value);
                      if (guests != null && guests > 0) {
                        setState(() => _maxGuests = guests);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
