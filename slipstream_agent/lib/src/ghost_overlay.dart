import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'finder.dart';
import 'semantics.dart';

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
/// Each log entry is shown for [_chipDuration] and then removed. When the
/// overlay has been removed from the tree (e.g. after a hot restart), it
/// reinstalls itself on the next [log] or [install] call.
class GhostOverlay {
  GhostOverlay._();

  static const Duration _chipDuration = Duration(seconds: 3);
  static const Duration _semanticsDuration = Duration(seconds: 3);
  static const Duration _outlineDuration = Duration(milliseconds: 750);
  static const Duration _toastDuration = Duration(milliseconds: 280);

  static final GlobalKey<_GhostOverlayState> _key = GlobalKey();
  static OverlayEntry? _entry;

  /// The [OverlayState] that [_entry] was inserted into. Used to distinguish
  /// "entry inserted but widget not yet built on this overlay" from "widget
  /// torn down and a new overlay was created" — the latter requires
  /// re-insertion even though [_entry] is non-null.
  static OverlayState? _targetOverlay;

  /// The queue of entries waiting to be handed to the widget.
  static final List<_LogMessage> _pending = [];

  static bool _visible = true;

  // Persistent error state — source of truth; the widget state mirrors this.
  static int _errorCount = 0;
  static String _errorSummary = '';

  /// Records a new `flutter.error` event and shows the persistent error banner.
  ///
  /// The banner displays a running count and the most recent [summary]. Call
  /// [clearErrors] to dismiss it (e.g. after the agent has read the logs or
  /// after a hot reload).
  static void showError(String summary) {
    _errorCount++;
    _errorSummary = summary;
    _key.currentState?.setError(_errorCount, _errorSummary);
    _ensureInstalled();
  }

  /// Clears the persistent error banner.
  static void clearErrors() {
    _errorCount = 0;
    _errorSummary = '';
    _key.currentState?.setError(0, '');
  }

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
    _pending.add(_LogMessage(
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

    if (_entry != null && overlay == _targetOverlay) {
      // Entry was inserted into this overlay but the widget hasn't built yet
      // (OverlayEntry.mounted is only true after the first build). Don't
      // insert a second entry — that would produce a GlobalKey conflict.
      return;
    }

    // New overlay (first install or widget tree was rebuilt after a hot
    // restart / test teardown).
    WidgetsApp.debugAllowBannerOverride = false;

    _targetOverlay = overlay;
    _entry = OverlayEntry(builder: (_) => _GhostOverlayWidget(key: _key));
    overlay.insert(_entry!);

    // The widget state is not built until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPending());
  }

  static void _flushPending() {
    final state = _key.currentState;
    if (state == null) return;
    if (_pending.isNotEmpty) {
      for (final entry in _pending) {
        state.addLogMessage(entry);
      }
      _pending.clear();
    }
    if (_errorCount > 0) {
      state.setError(_errorCount, _errorSummary);
    }
  }

  static OverlayState? _findOverlay() {
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) return null;

    // Walk the element tree depth-first.  The first OverlayState encountered
    // is the outermost one (closest to the root) — exactly where we want to
    // insert so the overlay paints above all app content.
    OverlayState? result;
    void visit(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.state is OverlayState) {
        result = element.state as OverlayState;
        return;
      }
      element.visitChildren(visit);
    }

    rootElement.visitChildren(visit);

    // Fallback: walk to the deepest leaf element and ask Flutter's own
    // `Overlay.maybeOf()` to walk back up to the nearest Overlay ancestor. This
    // handles unusual configurations where the DFS ordering could pick the
    // wrong Overlay (e.g. a deeply-nested Navigator appearing earlier in the
    // visit order).
    if (result == null) {
      Element? leaf;
      void findLeaf(Element element) {
        leaf = element;
        element.visitChildren(findLeaf);
      }

      rootElement.visitChildren(findLeaf);
      if (leaf != null) {
        result = Overlay.maybeOf(leaf!);
      }
    }

    return result;
  }
}

// ---------------------------------------------------------------------------
// Widget

// Slipstream blue.
const Color ghostOverlayColor = Color(0xFF1565C0);

class _GhostOverlayWidget extends StatefulWidget {
  const _GhostOverlayWidget({super.key});

  @override
  State<_GhostOverlayWidget> createState() => _GhostOverlayState();
}

class _LogMessage {
  static int _nextId = 0;

  _LogMessage({
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

// ---------------------------------------------------------------------------
// Ghost overlay state

class _GhostOverlayState extends State<_GhostOverlayWidget> {
  final List<_LogMessage> _entries = [];
  final Map<int, GlobalKey<_EntryChipState>> _chipKeys = {};
  final List<Timer> _timers = [];

  bool _visible = true;

  // Persistent error display — mirrors GhostOverlay._errorCount/Summary.
  int _errorCount = 0;
  String _errorSummary = '';

  void setError(int count, String summary) {
    if (!mounted) return;
    setState(() {
      _errorCount = count;
      _errorSummary = summary;
    });
  }

  // Trigger counters and data for the three visualization sub-widgets.
  // Incrementing a counter causes the corresponding widget to start its
  // animation via didUpdateWidget; no GlobalKeys needed.
  int _flashCount = 0;
  Rect? _outlineRect;
  int _outlineCount = 0;
  List<({Rect rect, String label})> _semanticsRects = const [];
  int _semanticsCount = 0;

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
        _outlineRect = null;
        _semanticsRects = const [];
        _errorCount = 0;
        _errorSummary = '';
      } else {
        _errorCount = GhostOverlay._errorCount;
        _errorSummary = GhostOverlay._errorSummary;
      }
    });
  }

  void addLogMessage(_LogMessage entry) {
    if (!mounted) return;

    // Capture currently visible chips — they'll be bumped out immediately.
    final toExit = List.of(_entries);

    final key = GlobalKey<_EntryChipState>();
    setState(() {
      _entries.add(entry);
      _chipKeys[entry.id] = key;
    });

    // Bump any existing chip out now rather than waiting for its timer.
    for (final existing in toExit) {
      _chipKeys[existing.id]?.currentState?.triggerExit();
    }

    if (entry.viz == 'flash') setState(() => _flashCount++);
    if ((entry.viz == 'outline' || entry.viz == 'layout') &&
        entry.finder != null &&
        entry.finderValue != null) {
      // TODO: 'layout' could get a specialized visualization (padding overlays,
      // flex annotations, etc.) once ext.slipstream.inspect_layout is
      // implemented with in-process finder support.
      _triggerOutline(entry.finder!, entry.finderValue!);
    }
    if (entry.viz == 'semantics') _triggerSemantics();

    _timers.add(Timer(GhostOverlay._chipDuration, () {
      if (!mounted) return;
      _chipKeys[entry.id]?.currentState?.triggerExit();
    }));
  }

  void _triggerOutline(String finder, String finderValue) {
    final el = findElement(finder: finder, value: finderValue);
    final box = el?.renderObject;
    if (box is RenderBox && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      setState(() {
        _outlineRect = rect;
        _outlineCount++;
      });
    }
  }

  void _triggerSemantics() {
    final (nodes, _) = getSemanticsNodes();
    if (nodes == null || nodes.isEmpty) return;

    final rects = [
      for (final node in nodes)
        (
          rect: node.screenRect,
          label: _semanticsLabel(node),
        ),
    ];

    setState(() {
      _semanticsRects = rects;
      _semanticsCount++;
    });
  }

  static String _semanticsLabel(SemanticsNodeInfo node) {
    final label = node.label.trim();
    if (label.isNotEmpty) {
      return label.length > 18 ? '${label.substring(0, 16)}…' : label;
    }
    return node.role ?? 'text';
  }

  void _onChipExited(_LogMessage entry) {
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
      _outlineRect = null;
      _semanticsRects = const [];
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload — clear accumulated errors so the banner resets cleanly.
    GhostOverlay.clearErrors();
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

    final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0.0;

    return IgnorePointer(
      child: Stack(
        // StackFit.expand ensures the Stack fills the Overlay's area even when
        // the Overlay passes loose rather than tight constraints.  Without it,
        // the Stack would shrink-wrap its non-positioned children
        // (_FlashOverlay / _OutlineOverlay / _SemanticsOverlay all return
        // SizedBox.shrink() when idle), collapsing to 0×0 and hiding the
        // Positioned.fill banner.
        fit: StackFit.expand,
        children: [
          // Brief white full-screen tint for viz:"flash" entries.
          _FlashOverlay(triggerCount: _flashCount),
          // Bounding-box highlight for viz:"outline" entries.
          _OutlineOverlay(rect: _outlineRect, triggerCount: _outlineCount),
          // Per-node bounding boxes for viz:"semantics" entries.
          _SemanticsOverlay(
              rects: _semanticsRects, triggerCount: _semanticsCount),
          // Slipstream banner — replaces the Flutter debug banner.
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
          // Persistent error banner near the top of the screen.
          if (_errorCount > 0)
            Positioned(
              top: (MediaQuery.maybePaddingOf(context)?.top ?? 0.0) + 18,
              left: 12,
              right: 12,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  _ErrorBanner(count: _errorCount, summary: _errorSummary),
                ],
              ),
            ),
          // Command-log chips — share the same space; newer chips are
          // painted in front of older ones.
          if (_entries.isNotEmpty)
            Positioned(
              bottom: bottomInset + 36,
              left: 12,
              right: 12,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
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

// ---------------------------------------------------------------------------
// Visualization widgets

/// Brief full-screen white tint, triggered when [triggerCount] increments.
class _FlashOverlay extends StatefulWidget {
  const _FlashOverlay({required this.triggerCount});

  final int triggerCount;

  @override
  State<_FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<_FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Quick fade-in → brief hold → slow fade-out.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.65), weight: 12), // ~72ms
      TweenSequenceItem(tween: ConstantTween(0.65), weight: 13), // ~78ms hold
      TweenSequenceItem(
          tween: Tween(begin: 0.65, end: 0.0), weight: 75), // ~450ms
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_FlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerCount != oldWidget.triggerCount) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        return Positioned.fill(
          child: ColoredBox(
            color: Color.fromRGBO(255, 255, 255, _opacity.value),
          ),
        );
      },
    );
  }
}

/// Animated bounding-box highlight for a single widget.
/// Starts its animation when [triggerCount] increments; hides when [rect] is null.
class _OutlineOverlay extends StatefulWidget {
  const _OutlineOverlay({required this.rect, required this.triggerCount});

  final Rect? rect;
  final int triggerCount;

  @override
  State<_OutlineOverlay> createState() => _OutlineOverlayState();
}

class _OutlineOverlayState extends State<_OutlineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GhostOverlay._outlineDuration,
    );
    // Double flash: fade-in → fade-out → fade-in → fade-out.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 15), // ~135ms
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 20), // ~180ms
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 15), // ~135ms
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 50), // ~450ms
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_OutlineOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rect == null) {
      _controller.reset();
    } else if (widget.triggerCount != oldWidget.triggerCount) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.rect;
    if (rect == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        return Positioned.fromRect(
          rect: rect.inflate(3),
          child: Opacity(
            opacity: _opacity.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: ghostOverlayColor, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated bounding-box overlay for all visible semantics nodes.
/// Starts its animation when [triggerCount] increments; hides when [rects] is empty.
class _SemanticsOverlay extends StatefulWidget {
  const _SemanticsOverlay({required this.rects, required this.triggerCount});

  final List<({Rect rect, String label})> rects;
  final int triggerCount;

  @override
  State<_SemanticsOverlay> createState() => _SemanticsOverlayState();
}

class _SemanticsOverlayState extends State<_SemanticsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GhostOverlay._semanticsDuration,
    );
    // Fade-in → hold → fade-out.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0), weight: 10), // ~300ms
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60), // ~1800ms hold
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0), weight: 30), // ~900ms
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_SemanticsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rects.isEmpty) {
      _controller.reset();
    } else if (widget.triggerCount != oldWidget.triggerCount) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rects.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        final opacity = _opacity.value;
        return Stack(
          children: [
            for (final item in widget.rects)
              Positioned.fromRect(
                rect: item.rect.deflate(1.5),
                child: Opacity(
                  opacity: opacity,
                  child: _SemanticsNodeWidget(label: item.label),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Border box with a small label badge in the top-right corner, used to
/// render a single semantics node in the [_SemanticsOverlay].
class _SemanticsNodeWidget extends StatelessWidget {
  const _SemanticsNodeWidget({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: ghostOverlayColor, width: 1.5),
          ),
          child: const SizedBox.expand(),
        ),
        if (label.isNotEmpty)
          Positioned(
            top: -1,
            right: -1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: ghostOverlayColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Persistent error banner

const Color _errorColor = Color(0xFFB71C1C);

const TextStyle _errorTextStyle = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 12 * 0.85,
  fontWeight: FontWeight.w900,
  decoration: TextDecoration.none,
);

final BoxDecoration _errorDecoration = BoxDecoration(
  color: _errorColor,
  borderRadius: BorderRadius.circular(6),
  boxShadow: const [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ],
);

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.count, required this.summary});

  final int count;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final errorDesc =
        summary == null ? 'flutter.error' : 'flutter.error: $summary';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // error count
        DecoratedBox(
          decoration: _errorDecoration,
          child: Padding(
            padding:
                const EdgeInsets.only(left: 8, right: 8, top: 1, bottom: 3),
            child: Text('$count', style: _errorTextStyle),
          ),
        ),

        SizedBox(width: 4),

        // error icon and message
        DecoratedBox(
          decoration: _errorDecoration,
          child: Padding(
            padding:
                const EdgeInsets.only(left: 8, right: 8, top: 1, bottom: 3),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 11, color: const Color(0xFFFFFFFF)),
                const SizedBox(width: 4),
                Text(
                  errorDesc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _errorTextStyle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Command-log chip

class _EntryChip extends StatefulWidget {
  const _EntryChip({super.key, required this.entry, required this.onExited});

  final _LogMessage entry;
  final VoidCallback onExited;

  @override
  State<_EntryChip> createState() => _EntryChipState();
}

class _EntryChipState extends State<_EntryChip> with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _exitController;
  late final Animation<Offset> _enterSlide;
  late final Animation<Offset> _exitSlide;

  @override
  void initState() {
    super.initState();

    _enterController =
        AnimationController(vsync: this, duration: GhostOverlay._toastDuration)
          ..forward();
    _exitController =
        AnimationController(vsync: this, duration: GhostOverlay._toastDuration);

    // Values are fractions of the screen height (0.1 = 10% of screen height).
    _enterSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOut));

    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.1),
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

  static IconData? _iconForKind(String? kind) => switch (kind) {
        'reload' => Icons.refresh,
        'screenshot' => Icons.photo_camera,
        'read' => Icons.visibility,
        'interact' => Icons.touch_app,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final label = widget.entry.details != null
        ? '${widget.entry.command}: ${widget.entry.details}'
        : widget.entry.command;
    final icon = _iconForKind(widget.entry.kind);

    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _exitController]),
      builder: (context, child) {
        final screenH = MediaQuery.sizeOf(context).height;
        final dy = (_enterSlide.value.dy + _exitSlide.value.dy) * screenH;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: const Color(0xFFFFFFFF)),
                const SizedBox(width: 4),
              ],
              Text(
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
            ],
          ),
        ),
      ),
    );
  }
}
