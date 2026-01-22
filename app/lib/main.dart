import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyOtherPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class MyOtherPage extends StatefulWidget {
  const MyOtherPage({super.key, required this.title});
        
  final String title;

  @override
  State<MyOtherPage> createState() => _MyOtherPageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
class _MyOtherPageState extends State<MyOtherPage> {
  List<Offset> points = [];
  final Random _random = Random();
  final int zigs = 10;
  final double width = 3.0;

  @override
  void initState() {
    super.initState();
  }

  void _paintZigZagLine() {
    setState(() {
      points.add(Offset(_random.nextDouble() * 400, _random.nextDouble() * 400));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(400, 400),
              painter: ZigZagLinePainter(
                points: points,
                zigs: zigs,
                color: Colors.deepPurple,
                width: width,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _paintZigZagLine,
        tooltip: 'Paint',
        child: const Icon(Icons.brush),
      ),
    );
  }
}

class ZigZagLinePainter extends CustomPainter {
  final List<Offset> points;
  final int zigs;
  final Color color;
  final double width;

  ZigZagLinePainter({
    required this.points,
    required this.zigs,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final Path path = Path()..moveTo(points[0].dx, points[0].dy);

    for (int seg = 0; seg < points.length - 1; seg++) {
      final Offset start = points[seg];
      final Offset end = points[seg + 1];
      final double dx = end.dx - start.dx;
      final double dy = end.dy - start.dy;

      for (int i = 1; i <= zigs; i++) {
        final double t = i / zigs;
        final double xOffset = dx * t;
        final double yOffset = dy * t;
        final double perpendicularX = -dy;
        final double perpendicularY = dx;
        final double magnitude = sqrt(perpendicularX * perpendicularX + perpendicularY * perpendicularY);
        final double normalizedX = perpendicularX / magnitude;
        final double normalizedY = perpendicularY / magnitude;
        final double zigZagOffset = (i % 2 == 0) ? 20 : -20;

        path.lineTo(
          start.dx + xOffset + normalizedX * zigZagOffset,
          start.dy + yOffset + normalizedY * zigZagOffset,
        );
      }

      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ZigZagLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.zigs != zigs ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
