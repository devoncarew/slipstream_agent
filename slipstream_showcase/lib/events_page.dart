import 'dart:io';

import 'package:flutter/material.dart';

import 'common.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Header.
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 40,
          child: Icon(Icons.satellite_alt, size: 40),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Mission Control',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),

        // Debug output actions.
        const SectionHeader('Telemetry'),
        _ActionTile(
          icon: Icons.terminal,
          title: 'Call print',
          subtitle: 'Calls the dart:core print function',
          onTap: () {
            // ignore: avoid_print
            print('Hello from print — ${DateTime.now()}');
          },
        ),
        _ActionTile(
          icon: Icons.terminal,
          title: 'Print to stdout',
          // stdout is available on macOS/Linux desktop; not on iOS/Android.
          subtitle: 'Writes a line to dart:io stdout (desktop only)',
          onTap: () {
            stdout.writeln('Hello from stdout — ${DateTime.now()}');
          },
        ),

        // Error trigger actions.
        const SectionHeader('Fault Simulation'),
        _ActionTile(
          icon: Icons.swap_vert,
          title: 'RenderFlex overflow',
          subtitle: 'Column children exceed their container height',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const _OverflowErrorPage()),
          ),
        ),
        _ActionTile(
          icon: Icons.height,
          title: 'Unbounded viewport height',
          subtitle: 'ListView inside Column without Expanded',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const _UnboundedHeightPage(),
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.bug_report,
          title: 'Failed assertion',
          subtitle: 'Throws an AssertionError via assert(false)',
          onTap: () {
            assert(
              false,
              'Manually triggered assertion failure from Mission Control.',
            );
          },
        ),
        _ActionTile(
          icon: Icons.block,
          title: 'Null check on null value',
          subtitle: 'Null check operator used on a null value',
          onTap: () {
            String? value;
            // ignore: unused_local_variable
            final _ = value!;
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Demonstrates a RenderFlex overflow: a Column with 20 fixed-height children
/// inside a 300 dp tall container.
class _OverflowErrorPage extends StatelessWidget {
  const _OverflowErrorPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overflow error')),
      body: SizedBox(
        height: 300,
        child: Column(
          children: [
            for (int i = 1; i <= 20; i++)
              Container(
                height: 60,
                color: i.isOdd ? Colors.blue.shade200 : Colors.blue.shade100,
                alignment: Alignment.center,
                child: Text('Item $i'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Demonstrates "Vertical viewport was given unbounded height".
///
/// The broken layout (ListView directly in Column without Expanded) is not
/// rendered directly because it makes the entire page non-interactive. Instead
/// a button reports the error via [FlutterError.reportError], which produces
/// the same output format as the real layout error.
class _UnboundedHeightPage extends StatelessWidget {
  const _UnboundedHeightPage();

  static void _triggerError() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts([
          ErrorSummary('Vertical viewport was given unbounded height.'),
          ErrorDescription(
            'Viewports expand in the scrolling direction to fill their '
            'container. In this case, a vertical viewport was given an '
            'unlimited amount of vertical space in which to expand. This '
            'situation typically happens when a scrollable widget is nested '
            'inside another scrollable widget.',
          ),
          ErrorHint(
            'If this widget is always nested in a scrollable widget there is '
            'no need to use a viewport because there will always be enough '
            'vertical space for the children. In this case, consider using a '
            'Column or Wrap instead. Otherwise, consider using a '
            'CustomScrollView to concatenate arbitrary slivers into a single '
            'scrollable.',
          ),
        ]),
        library: 'rendering library',
        context: ErrorDescription('during performLayout()'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unbounded height error')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              'Tap the button to report a simulated\nunbounded height error.',
              textAlign: TextAlign.center,
            ),
            FilledButton(
              onPressed: _triggerError,
              child: Text('Trigger error'),
            ),
          ],
        ),
      ),
    );
  }
}
