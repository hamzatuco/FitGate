import 'package:flutter/material.dart';

/// Confirmation dialog for destructive actions
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmButtonText;
  final String cancelButtonText;
  final Color confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmButtonText = 'Confirm',
    this.cancelButtonText = 'Cancel',
    this.confirmColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelButtonText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
          ),
          child: Text(
            confirmButtonText,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmButtonText = 'Confirm',
    String cancelButtonText = 'Cancel',
    Color confirmColor = Colors.red,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        confirmColor: confirmColor,
      ),
    );
  }
}
