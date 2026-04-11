import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'model.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dataModel = context.watch<StellarData>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final discovery in dataModel.discoveries)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                size: 48,
                discovery.icon,
                color: theme.colorScheme.primary,
              ),
              title: Text(discovery.name),
              subtitle: Text(discovery.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.goNamed(
                  'discovery_details',
                  pathParameters: {'object_id': discovery.id},
                );
              },
            ),
          ),
      ],
    );
  }
}

class DiscoverDetailPage extends StatelessWidget {
  final String objectId;

  const DiscoverDetailPage({super.key, required this.objectId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stellarData = context.watch<StellarData>();
    final discovery = stellarData.getById(objectId);

    if (discovery == null) {
      return Center(child: Text('Stellar object unknown: $objectId'));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        // Flutter's AppBar automatically inserts a BackButton here, which uses
        // Icons.adaptive.arrow_back — a left-chevron on iOS and a left-arrow on
        // Android — so the back affordance matches the emulated platform.
        title: Text(discovery.name),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Icon(discovery.icon, size: 96, color: theme.colorScheme.primary),
            Text(discovery.name, style: theme.textTheme.headlineSmall),
            Text(
              discovery.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
