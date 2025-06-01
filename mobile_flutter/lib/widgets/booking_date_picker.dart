import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;
  final List<DateTime> availableDates;

  const BookingDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
    required this.availableDates,
  });

  @override
  State<BookingDatePicker> createState() => _BookingDatePickerState();
}

class _BookingDatePickerState extends State<BookingDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
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
          'Выберите дату заселения',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    selectableDayPredicate: (DateTime date) {
                      return _isDateAvailable(date);
                    },
                  );

                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                      widget.onDateSelected(picked);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
