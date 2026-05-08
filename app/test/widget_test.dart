import 'package:app/counter_bloc.dart';
import 'package:app/counter_page.dart';
import 'package:app/drawing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
 group('CounterPage', () {
    late Widget counter;

    setUp(() {
      counter = BlocProvider(
        create: (_) => CounterBloc(),
        child: MaterialApp(home: CounterPage()),
      );
      print('→ Starting a new CounterPage test');
    });

    testWidgets('Counter smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('Counter increment test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('Counter decrement test', (WidgetTester tester) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.text('1'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Counter decrement constraint test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(counter);

      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      expect(find.text('1'), findsNothing);
      expect(find.text('-1'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('DrawingPage', () {
    late Widget drawing;

    setUp(() {
      drawing = MaterialApp(home: const DrawingPage(title: 'Drawing'));
      print('→ Starting a new DrawingPage test');
    });

    testWidgets('Drawing Page smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(drawing);

      final state = tester.state<DrawingPageState>(find.byType(DrawingPage));

      expect(find.byIcon(Icons.brush), findsOneWidget);
      expect(state.points.length, 0);
    });

    testWidgets('adds a point to drawing', (WidgetTester tester) async {
      await tester.pumpWidget(drawing);

      final state = tester.state<DrawingPageState>(find.byType(DrawingPage));

      await tester.tap(find.byIcon(Icons.brush));
      await tester.pump();

      expect(state.points.length, 1);
    });
  });
}
