import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secbizcard/core/errors/failure.dart';

extension AsyncValueUI on AsyncValue<dynamic> {
  void showSnackbarOnError(BuildContext context) {
    if (!isLoading && hasError) {
      final message = _getErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  String _getErrorMessage(Object? error) {
    if (error is Failure) {
      return error.message;
    }
    return error.toString();
  }
}
