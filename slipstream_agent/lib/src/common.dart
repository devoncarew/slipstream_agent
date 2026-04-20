import 'dart:async';

import 'package:flutter/material.dart';

/// Waits for the widget tree to settle, similar to Flutter's test
/// [pumpAndSettle], but adapted for a live app where infinite animations may
/// be running.
///
/// Rather than waiting for *all* frames to stop (which never happens with
/// looping animations), this function waits until [idleThreshold] consecutive
/// ~16 ms intervals pass with no new frame scheduled. That is enough quiet
/// time for navigation transitions, Hero animations, and most one-shot UI work
/// to complete.
///
/// If [timeout] elapses first the function returns silently — it never throws.
Future<void> pumpAndMostlySettle({
  Duration step = const Duration(milliseconds: 16),
  Duration timeout = const Duration(seconds: 5),
  int idleThreshold = 5,
}) async {
  final binding = WidgetsBinding.instance;
  final endTime = DateTime.now().add(timeout);
  var idleCount = 0;

  while (idleCount < idleThreshold) {
    if (DateTime.now().isAfter(endTime)) return;

    if (binding.hasScheduledFrame) {
      idleCount = 0;
      final completer = Completer<void>();
      binding.addPostFrameCallback((_) => completer.complete());
      await completer.future;
    } else {
      idleCount++;
      await Future.delayed(step);
    }
  }
}
