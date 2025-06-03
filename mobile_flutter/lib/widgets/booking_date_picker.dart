import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? endDate;
  final Function(DateTime, DateTime?) onDatesSelected;
  final List<DateTime> availableDates;

  const BookingDatePicker({
    super.key,
    required this.initialDate,
    this.endDate,
    required this.onDatesSelected,
    required this.availableDates,
  });

  @override
  State<BookingDatePicker> createState() => _BookingDatePickerState();
}

class _BookingDatePickerState extends State<BookingDatePicker> {
  late DateTime _checkInDate;
  DateTime? _checkOutDate;

  @override
  void initState() {
    super.initState();
    _checkInDate = widget.initialDate;
    _checkOutDate = widget.endDate;
  }

  bool _isDateAvailable(DateTime date) {
    return widget.availableDates.any((availableDate) =>
        availableDate.year == date.year &&
        availableDate.month == date.month &&
        availableDate.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Период бронирования',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Дата заезда: ${DateFormat('dd MMMM yyyy').format(_checkInDate)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _checkInDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        selectableDayPredicate: (DateTime date) {
                          return _isDateAvailable(date);
                        },
                      );

                      if (picked != null && picked != _checkInDate) {
                        setState(() {
                          _checkInDate = picked;
                          widget.onDatesSelected(picked, _checkOutDate);
                        });
                      }
                    },
                  ),
                ],
              ),
              if (_checkOutDate != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Дата выезда: ${DateFormat('dd MMMM yyyy').format(_checkOutDate!)}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _checkOutDate!,
                          firstDate: _checkInDate.add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          selectableDayPredicate: (DateTime date) {
                            return _isDateAvailable(date);
                          },
                        );

                        if (picked != null && picked != _checkOutDate) {
                          setState(() {
                            _checkOutDate = picked;
                            widget.onDatesSelected(_checkInDate, picked);
                          });
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
