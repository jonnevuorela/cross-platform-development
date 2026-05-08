import 'package:app/counter_bloc.dart';
import 'package:app/counter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => CounterBloc(),
        child: MaterialApp(home: CounterPage()),
      ),
    );

    // Increment all the way to 3 and decrease back to zero but not negative.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(find.text('3'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('0'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('-1'), findsNothing);
    expect(find.text('0'), findsOneWidget);
  });
}
