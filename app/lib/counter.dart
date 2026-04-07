import 'package:flutter/foundation.dart';
import 'dart:convert';

@immutable
class CounterModel {
  const CounterModel({
    required this.username,
    this.counter = 0,
  });

  final String username;
  final int counter;

  CounterModel copyWith({
    String? username,
    int? counter,
  }) {
    return CounterModel(
      username: username ?? this.username,
      counter: counter ?? this.counter,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'counter': counter,
    };
  }

  factory CounterModel.fromMap(Map<String, dynamic> map) {
    return CounterModel(
      username: map['username'] as String,
      counter: map['counter'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory CounterModel.fromJson(String source) => CounterModel.fromMap(Map<String, dynamic>.from(json.decode(source)));

  @override
  String toString() =>
      'CounterModel(username: $username, counter: $counter)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CounterModel &&
        other.username == username &&
        other.counter == counter;
  }

  @override
  int get hashCode =>
      username.hashCode ^ counter.hashCode;
}

class CounterNotifier extends ValueNotifier<CounterModel> {
  CounterNotifier(super.state);

  void increment() {
    value = value.copyWith(counter: value.counter + 1);
  }
}
