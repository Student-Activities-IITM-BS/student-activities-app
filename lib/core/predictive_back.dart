import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_activities/core/app_preferences.dart';

class PredictiveBackScope extends StatelessWidget {
  const PredictiveBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) => PopScope(
        canPop: AppPreferences.instance.predictiveBack,
        onPopInvokedWithResult: (didPop, _) {
          FocusManager.instance.primaryFocus?.unfocus(
            disposition: UnfocusDisposition.scope,
          );
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          if (!didPop && !AppPreferences.instance.predictiveBack) {
            Navigator.of(context).pop();
          }
        },
        child: child,
      ),
    );
  }
}
