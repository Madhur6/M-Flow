import 'package:flutter/material.dart';
import 'package:m_flow/pages/dashboard.dart';
import 'pages/form_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FormPage(),
    );
  }
}