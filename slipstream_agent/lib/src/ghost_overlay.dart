import 'dart:async';

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Public API

/// Displays a transient command log above the app's widget tree.
///
/// Call [log] to add an entry. The overlay locates the first [OverlayState]
/// in the widget tree and inserts itself lazily — no app-side setup is
/// required beyond calling [SlipstreamAgent.init].
///
/// Each entry is shown for [_displayDuration] and then removed. When the
/// overlay has been removed from the tree (e.g. after a hot restart), it
/// reinstalls itself on the next [log] call.
class GhostOverlay {
  GhostOverlay._();

  static const Duration _displayDuration = Duration(seconds: 3);
  static const int _maxEntries = 5;

  static final GlobalKey<_GhostOverlayState> _key = GlobalKey();
  static OverlayEntry? _entry;

  /// The queue of (command, details) pairs waiting to be handed to the widget.
  static final List<(String, String?)> _pending = [];

  /// Controls whether the ghost overlay is visible.
  ///
  /// Set to `false` to suppress new entries and clear any currently visible
  /// chips (e.g. before taking a screenshot). Set back to `true` to resume
  /// normal display. Mirrors the role of [WidgetsApp.debugAllowBannerOverride]
  /// for the debug banner.
  static bool overlayEnabled = true;

  /// Shows [command] (and optional [details]) in the command log overlay.
  ///
  /// If [overlayEnabled] is `false` the call is silently ignored.
  /// If the overlay is not yet in the tree it is installed first; any entries
  /// that arrive before the first build are queued and replayed once the
  /// widget state is available.
  static void log(String command, {String? details}) {
    if (!overlayEnabled) return;
    _pending.add((command, details));
    _ensureInstalled();
  }

  /// Clears all currently visible chips immediately.
  static void clearEntries() {
    _pending.clear();
    _key.currentState?.clearEntries();
  }

  // ---------------------------------------------------------------------------
  // Installation

  static void _ensureInstalled() {
    if (_entry != null && _entry!.mounted) {
      _flushPending();
      return;
    }

    final overlay = _findOverlay();
    if (overlay == null) {
      // Widget tree not ready yet — retry after the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInstalled());
      return;
    }

    _entry = OverlayEntry(builder: (_) => _GhostOverlayWidget(key: _key));
    overlay.insert(_entry!);

    // The widget state is not built until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPending());
  }

  static void _flushPending() {
    final state = _key.currentState;
    if (state == null || _pending.isEmpty) return;
    for (final (command, details) in _pending) {
      state.addEntry(command, details);
    }
    _pending.clear();
  }

  static OverlayState? _findOverlay() {
    OverlayState? result;
    void visit(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.state is OverlayState) {
        result = element.state as OverlayState;
        return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }
}

// ---------------------------------------------------------------------------
// Widget

class _GhostOverlayWidget extends StatefulWidget {
  const _GhostOverlayWidget({super.key});

  @override
  State<_GhostOverlayWidget> createState() => _GhostOverlayState();
}

class _LogEntry {
  static int _nextId = 0;

  _LogEntry({required this.command, this.details}) : id = _nextId++;

  final int id;
  final String command;
  final String? details;
}

class _GhostOverlayState extends State<_GhostOverlayWidget> {
  final List<_LogEntry> _entries = [];
  final List<Timer> _timers = [];

  void addEntry(String command, String? details) {
    if (!mounted) return;
    final entry = _LogEntry(command: command, details: details);
    setState(() {
      _entries.add(entry);
      if (_entries.length > GhostOverlay._maxEntries) {
        _entries.removeAt(0);
      }
    });
    _timers.add(Timer(GhostOverlay._displayDuration, () {
      if (!mounted) return;
      setState(() => _entries.removeWhere((e) => e.id == entry.id));
    }));
  }

  void clearEntries() {
    if (!mounted) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() => _entries.clear());
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();

    // OverlayEntry builds inside the Overlay's Stack, so Positioned works
    // directly here. Use MediaQuery for safe-area insets when available.
    final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0.0;

    return Positioned(
      bottom: bottomInset + 12,
      right: 12,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _entries) _EntryChip(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final label = entry.details != null
        ? '${entry.command}: ${entry.details}'
        : entry.command;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Slipstream blue, semi-opaque so the app beneath remains visible.
          color: const Color(0xE01565C0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.normal,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
