import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

class BookingCancellationDialog extends StatelessWidget {
  final Booking booking;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const BookingCancellationDialog({
    super.key,
    required this.booking,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отмена бронирования'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вы уверены, что хотите отменить бронирование?\n\n'
            'Дата заезда: ${DateFormat('dd MMMM yyyy').format(booking.startDate)}\n'
            'Дата выезда: ${DateFormat('dd MMMM yyyy').format(booking.endDate)}\n'
            'Количество гостей: ${booking.guests} человек',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'После отмены бронирования деньги будут возвращены в течение 3-5 рабочих дней.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Отменить бронирование'),
        ),
      ],
    );
  }
}
