import 'dart:async';

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Public API

/// Displays a transient command log and a "slipstream" banner above the app's
/// widget tree.
///
/// Call [install] once (e.g. on the first [ext.slipstream.ping]) to disable
/// the Flutter debug banner and show the Slipstream banner. Call [log] to add
/// command-log entries. Call [setVisible] to hide/show everything (e.g. before
/// taking a screenshot).
///
/// The overlay locates the first [OverlayState] in the widget tree and inserts
/// itself lazily — no app-side setup is required beyond calling
/// [SlipstreamAgent.init].
///
/// Each log entry is shown for [_displayDuration] and then removed. When the
/// overlay has been removed from the tree (e.g. after a hot restart), it
/// reinstalls itself on the next [log] or [install] call.
class GhostOverlay {
  GhostOverlay._();

  static const Duration _displayDuration = Duration(seconds: 3);
  static const int _maxEntries = 5;

  static final GlobalKey<_GhostOverlayState> _key = GlobalKey();
  static OverlayEntry? _entry;

  /// The queue of entries waiting to be handed to the widget.
  static final List<_LogEntry> _pending = [];

  static bool _visible = true;

  /// Installs the ghost overlay and permanently disables the Flutter debug
  /// banner for the life of the Slipstream session.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops unless the
  /// overlay was removed from the tree (e.g. after a hot restart).
  static void install() {
    _ensureInstalled();
  }

  /// Shows [command] (and optional [details]) in the command log overlay.
  ///
  /// [kind] hints which icon to display: `"read"`, `"interact"`, `"reload"`, or
  /// `"screenshot"`. [finder] + [finderValue] identify a widget of interest
  /// for visualizations. [viz] names an extra visual effect: `"flash"`,
  /// `"outline"`, `"layout"`, or `"semantics"`.
  ///
  /// If the overlay is hidden (see [setVisible]) the call is silently ignored.
  /// If the overlay is not yet in the tree it is installed first; any entries
  /// that arrive before the first build are queued and replayed once the
  /// widget state is available.
  static void log(
    String command, {
    String? details,
    String? kind,
    String? finder,
    String? finderValue,
    String? viz,
  }) {
    if (!_visible) return;
    _pending.add(_LogEntry(
      command: command,
      details: details,
      kind: kind,
      finder: finder,
      finderValue: finderValue,
      viz: viz,
    ));
    _ensureInstalled();
  }

  /// Shows or hides the entire ghost overlay (banner + chips).
  ///
  /// Pass `false` before taking a screenshot to remove all Slipstream UI;
  /// pass `true` to restore it.
  static void setVisible(bool visible) {
    _visible = visible;
    if (!visible) {
      _pending.clear();
    }
    _key.currentState?.setVisible(visible);
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

    // Permanently disable the Flutter debug banner for this session.
    WidgetsApp.debugAllowBannerOverride = false;

    _entry = OverlayEntry(builder: (_) => _GhostOverlayWidget(key: _key));
    overlay.insert(_entry!);

    // The widget state is not built until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPending());
  }

  static void _flushPending() {
    final state = _key.currentState;
    if (state == null || _pending.isEmpty) return;
    for (final entry in _pending) {
      state.addEntry(entry);
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

// Slipstream blue.
const Color ghostOverlayColor = Color(0xFF1565C0);
// const Color ghostOverlayColor = Color(0xA01565C0);

class _GhostOverlayWidget extends StatefulWidget {
  const _GhostOverlayWidget({super.key});

  @override
  State<_GhostOverlayWidget> createState() => _GhostOverlayState();
}

class _LogEntry {
  static int _nextId = 0;

  _LogEntry({
    required this.command,
    this.details,
    this.kind,
    this.finder,
    this.finderValue,
    this.viz,
  }) : id = _nextId++;

  final int id;
  final String command;
  final String? details;

  /// Icon category hint: `"read"`, `"interact"`, `"reload"`, or `"screenshot"`.
  final String? kind;

  /// Finder type for the widget of interest (same values as `perform_action`).
  final String? finder;

  /// Finder value for the widget of interest.
  final String? finderValue;

  /// Extra visualization: `"flash"`, `"outline"`, `"layout"`, or `"semantics"`.
  final String? viz;
}

class _GhostOverlayState extends State<_GhostOverlayWidget> {
  final List<_LogEntry> _entries = [];
  final Map<int, GlobalKey<_EntryChipState>> _chipKeys = {};
  final List<Timer> _timers = [];

  bool _visible = true;

  void setVisible(bool visible) {
    if (!mounted) return;
    if (visible == _visible) return;
    if (!visible) {
      for (final t in _timers) {
        t.cancel();
      }
      _timers.clear();
    }
    setState(() {
      _visible = visible;
      if (!visible) {
        _entries.clear();
        _chipKeys.clear();
      }
    });
  }

  void addEntry(_LogEntry entry) {
    if (!mounted) return;
    final key = GlobalKey<_EntryChipState>();
    setState(() {
      if (_entries.length >= GhostOverlay._maxEntries) {
        final oldest = _entries.removeAt(0);
        _chipKeys.remove(oldest.id);
      }
      _entries.add(entry);
      _chipKeys[entry.id] = key;
    });
    _timers.add(Timer(GhostOverlay._displayDuration, () {
      if (!mounted) return;
      _chipKeys[entry.id]?.currentState?.triggerExit();
    }));
  }

  void _onChipExited(_LogEntry entry) {
    if (!mounted) return;
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
      _chipKeys.remove(entry.id);
    });
  }

  void clearEntries() {
    if (!mounted) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() {
      _entries.clear();
      _chipKeys.clear();
    });
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
    if (!_visible) return const SizedBox.shrink();

    // OverlayEntry builds inside the Overlay's Stack, so Positioned works
    // directly here. Use MediaQuery for safe-area insets when available.
    final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0.0;

    return IgnorePointer(
      child: Stack(
        children: [
          // Slipstream banner — replaces the Flutter debug banner in the
          // top-right corner.
          Positioned.fill(
            child: CustomPaint(
              painter: BannerPainter(
                message: 'slipstream',
                textDirection: TextDirection.ltr,
                layoutDirection: TextDirection.ltr,
                location: BannerLocation.topEnd,
                color: ghostOverlayColor,
              ),
            ),
          ),
          // Command-log chip stack in the bottom-right corner.
          if (_entries.isNotEmpty)
            Positioned(
              bottom: bottomInset + 24,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in _entries)
                    _EntryChip(
                      key: _chipKeys[entry.id],
                      entry: entry,
                      onExited: () => _onChipExited(entry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryChip extends StatefulWidget {
  const _EntryChip({super.key, required this.entry, required this.onExited});

  final _LogEntry entry;
  final VoidCallback onExited;

  @override
  State<_EntryChip> createState() => _EntryChipState();
}

class _EntryChipState extends State<_EntryChip> with TickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 280);

  late final AnimationController _enterController;
  late final AnimationController _exitController;
  late final Animation<Offset> _enterSlide;
  late final Animation<Offset> _exitSlide;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(vsync: this, duration: _animDuration)
      ..forward();
    _exitController = AnimationController(vsync: this, duration: _animDuration);

    _enterSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOut));

    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
  }

  /// Plays the exit animation then calls [_EntryChip.onExited].
  void triggerExit() {
    if (!mounted) return;
    if (_exitController.isAnimating || _exitController.isCompleted) return;
    _exitController.forward().then((_) {
      if (mounted) widget.onExited();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.entry.details != null
        ? '${widget.entry.command}: ${widget.entry.details}'
        : widget.entry.command;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: Listenable.merge([_enterController, _exitController]),
          builder: (context, child) => FractionalTranslation(
            translation: _enterSlide.value + _exitSlide.value,
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(const Color(0x28FFFFFF), ghostOverlayColor),
                  ghostOverlayColor,
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12 * 0.85,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
