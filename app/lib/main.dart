import 'package:app/nav_wrapper.dart';
import 'package:flutter/material.dart';

void main() {
  const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  runApp(const NavWrapper(useMock: useMock));
}
