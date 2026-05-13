import 'package:flutter/material.dart';

import 'app_messenger.dart';

class Toasts {
  static const double _baseOffset = 120;

  static void show(String message, {BuildContext? context}) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    final sourceContext = context ?? appMessengerKey.currentContext;
    final mediaQuery = sourceContext == null ? null : MediaQuery.of(sourceContext);
    final bottomInset = mediaQuery?.viewInsets.bottom ?? 0;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + _baseOffset),
      ),
    );
  }
}
