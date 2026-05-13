import 'package:app/src/rust/api/simple.dart';
import 'package:app/src/rust/frb_generated.dart';
import 'package:app/nav_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await RustLib.init();
  print(greet(name: "Jonne"));
  runApp(const NavWrapper(useMock: useMock));
}

//
//Future<void> main() async {
//  await RustLib.init();
//  runApp(const MyApp());
//}
//
//class MyApp extends StatelessWidget {
//  const MyApp({super.key});
//
//  @override
//  Widget build(BuildContext context) {
//    return MaterialApp(
//      home: Scaffold(
//        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//        body: Center(
//          child: Text(
//            'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
//          ),
//        ),
//      ),
//    );
//  }
//}
