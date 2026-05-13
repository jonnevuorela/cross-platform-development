import 'package:flutter_bloc/flutter_bloc.dart';

sealed class CounterEvent {}

final class CounterIncrementPressed extends CounterEvent {}

final class CounterDecrementPressed extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  final bool enableLogging;

  CounterBloc({this.enableLogging = true}) : super(0) {
    on<CounterIncrementPressed>((event, emit) => emit(state + 1));
    on<CounterDecrementPressed>((event, emit) {
      if (state > 0) {
        emit(state - 1);
      } else {
        emit(0);
      }
    });
  }

  @override
  void onEvent(CounterEvent event) {
    super.onEvent(event);
    if (enableLogging) print(event);
  }

  @override
  void onChange(Change<int> change) {
    super.onChange(change);
    if (enableLogging) print(change);
  }

  @override
  void onTransition(Transition<CounterEvent, int> transition) {
    super.onTransition(transition);
    if (enableLogging) print(transition);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('$error, $stackTrace');
    super.onError(error, stackTrace);
  }
}
