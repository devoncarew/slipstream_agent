import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/src/ghost_overlay.dart';
import 'package:slipstream_agent/src/overlays.dart';

void main() {
  group('setOverlaysEnabled', () {
    setUp(() {
      // Reset GhostOverlay visibility before each test.
      GhostOverlay.setVisible(true);
    });

    testWidgets('hides the ghost overlay when called with false',
        (tester) async {
      // pumpWidget installs the OverlayEntry (via post-frame callback).
      // First pump builds the widget and schedules _flushPending.
      // Second pump rebuilds with the chip visible.
      GhostOverlay.log('hello');
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);

      setOverlaysEnabled(false);
      await tester.pump();

      expect(find.text('hello'), findsNothing);
    });

    testWidgets('restores the ghost overlay when called with true',
        (tester) async {
      // Install the overlay first.
      GhostOverlay.log('setup');
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      await tester.pump();

      setOverlaysEnabled(false);
      await tester.pump();

      setOverlaysEnabled(true);
      // Entry is already mounted — log goes directly to the state.
      GhostOverlay.log('world');
      await tester.pump();

      expect(find.text('world'), findsOneWidget);
    });
  });
}
