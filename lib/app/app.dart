import 'package:flutter/material.dart';
import '../features/onboarding/welcome_screen.dart';
import 'theme/okae_theme.dart';

class OkaeApp extends StatelessWidget {
  const OkaeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OKAE',
    debugShowCheckedModeBanner: false,
    theme: okaeTheme(),
    home: const WelcomeScreen(),
  );
}
