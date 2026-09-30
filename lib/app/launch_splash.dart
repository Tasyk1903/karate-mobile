import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Matches the native launch screen while the saved session is restored.
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key});

  @override
  Widget build(BuildContext context) =>
      const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Image(
              image: AssetImage('assets/images/kr.jpg'),
              width: 192,
              height: 192,
              fit: BoxFit.contain,
              semanticLabel: 'KumiteRating',
            ),
          ),
        ),
      );
}
