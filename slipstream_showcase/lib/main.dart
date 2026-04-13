import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:slipstream_showcase/model.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

import 'common.dart';
import 'discover_page.dart';
import 'events_page.dart';
import 'widgets_page.dart';

// ---------------------------------------------------------------------------
// Observable globals — readable via the inspector's evaluate() tool.
//
// After tapping "Launch Mission" on the Widgets page:
//   evaluate('tapCount.toString()')   → "1", "2", …
//
// After set_text on the first text field:
//   evaluate('lastInput')             → the string that was typed
// ---------------------------------------------------------------------------

/// Incremented each time the primary action button on the Widgets page is
/// tapped. Use evaluate('tapCount.toString()') to read this value.
int tapCount = 0;

/// Updated on every keystroke in the first text field on the Widgets page.
/// Use evaluate('lastInput') to read this value.
String lastInput = '';

// ---------------------------------------------------------------------------

// Theme mode notifier — toggled by the app bar button, read by MaterialApp.
final _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void _cycleTheme() {
  _themeModeNotifier.value = switch (_themeModeNotifier.value) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_outlined,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System theme',
  ThemeMode.light => 'Light theme',
  ThemeMode.dark => 'Dark theme',
};

// ---------------------------------------------------------------------------

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  SlipstreamAgent.init(router: GoRouterAdapter(_router));

  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  // Stored here so Provider.value never recreates StellarData on theme change.
  final _stellarData = StellarData();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeModeNotifier,
      builder: (context, _) {
        return Provider<StellarData>.value(
          value: _stellarData,
          child: MaterialApp.router(
            title: 'Stellar',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: _themeModeNotifier.value,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
          ),
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/discover',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverPage(),
              routes: [
                GoRoute(
                  path: ':object_id',
                  name: 'discovery_details',
                  // Renders over the shell so the bottom nav is hidden on the
                  // detail page — gives get_route a richer stack to inspect.
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final objectId = state.pathParameters['object_id']!;
                    return DiscoverDetailPage(objectId: objectId);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/widgets',
              builder: (context, state) => const WidgetsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

typedef _MenuAction = void Function(BuildContext context);

void _showAbout(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'Stellar',
    applicationVersion: '1.0.0',
    children: const [
      Text(
        'A sample Flutter app used to test the flutter-slipstream MCP plugin.',
      ),
    ],
  );
}

void _refreshCatalog(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Catalog refreshed.')));
}

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Stellar'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _themeModeNotifier,
            builder: (context, value, _) {
              return IconButton(
                icon: Icon(_themeModeIcon(value)),
                tooltip: _themeModeLabel(value),
                onPressed: _cycleTheme,
              );
            },
          ),
          PopupMenuButton<_MenuAction>(
            icon: Icon(Icons.adaptive.more),
            onSelected: (action) => action(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _showAbout, child: Text('About Stellar')),
              PopupMenuItem(
                value: _refreshCatalog,
                child: Text('Refresh catalog'),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      // The drawer surfaces device info — useful for confirming what
      // environment the agent is running in.  Open via the hamburger button
      // (semantics label: "Open navigation menu") or via tap(label: 'Open
      // navigation menu').
      drawer: const _DeviceInfoDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: 'Widgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.satellite_alt_outlined),
            selectedIcon: Icon(Icons.satellite_alt),
            label: 'Events',
          ),
        ],
      ),
    );
  }
}

class _DeviceInfoDrawer extends StatelessWidget {
  const _DeviceInfoDrawer();

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mq = MediaQuery.of(context);

    final size = mq.size;
    final dpr = mq.devicePixelRatio;
    final padding = mq.padding;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Text(
              'Device info',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                InfoRow('Platform', platform.name),
                InfoRow(
                  'Screen size',
                  '${size.width.toStringAsFixed(0)} x '
                      '${size.height.toStringAsFixed(0)} pt',
                ),
                InfoRow('Pixel ratio', dpr.toStringAsFixed(3)),
                InfoRow(
                  'Safe area (LTRB)',
                  '${padding.left.toStringAsFixed(0)}, '
                      '${padding.top.toStringAsFixed(0)}, '
                      '${padding.right.toStringAsFixed(0)}, '
                      '${padding.bottom.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
