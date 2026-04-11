import 'package:flutter/material.dart';

import 'common.dart';
import 'main.dart' as app_globals;

class WidgetsPage extends StatefulWidget {
  const WidgetsPage({super.key});

  @override
  State<WidgetsPage> createState() => _WidgetsPageState();
}

class _WidgetsPageState extends State<WidgetsPage> {
  bool _trackingEnabled = false;
  bool _safetyChecked = false;
  double _apertureValue = 50.0;
  int _modeValue = 1;
  final TextEditingController _observerController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  @override
  void dispose() {
    _observerController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('showcase_scroll_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use this page to test agent interactions and semantic discovery.',
          ),
          const SizedBox(height: 32),

          // --- 1. TEXT INPUT ---
          Text(
            'Observer Entry',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          const SizedBox(height: 8),
          TextField(
            key: const Key('input_observer_name'),
            controller: _observerController,
            onChanged: (value) {
              // Update the top-level global so evaluate('lastInput') reflects
              // the current field content without requiring a hot reload.
              setState(() => app_globals.lastInput = value);
            },
            decoration: InputDecoration(
              labelText: 'Observer Name',
              hintText: 'Enter your name...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('clear_observer_button'),
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _observerController.clear();
                    app_globals.lastInput = '';
                  });
                },
                tooltip: 'Clear observer name',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_target_object'),
            controller: _targetController,
            decoration: InputDecoration(
              labelText: 'Target Object',
              hintText: 'e.g. Betelgeuse, M31...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('clear_target_button'),
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _targetController.clear()),
                tooltip: 'Clear target object',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 2. BUTTONS ---
          Text(
            'Mission Controls',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ElevatedButton(
                key: const Key('btn_launch_mission'),
                onPressed: () {
                  // Increment the top-level counter so the agent can verify
                  // this tap via evaluate('tapCount.toString()').
                  setState(() => app_globals.tapCount++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Mission launched! (tap #${app_globals.tapCount})',
                      ),
                    ),
                  );
                },
                child: const Text('Launch Mission'),
              ),
              OutlinedButton(
                key: const Key('btn_stand_down'),
                onPressed: () {},
                child: const Text('Stand Down'),
              ),
              IconButton(
                key: const Key('btn_favorite'),
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star),
                isSelected: _safetyChecked,
                onPressed: () {
                  setState(() => _safetyChecked = !_safetyChecked);
                },
                tooltip: 'Bookmark observation',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- 3. TOGGLES ---
          Text(
            'System Configuration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('toggle_tracking'),
            title: const Text('Enable Auto-Track'),
            subtitle: Text('Current state: $_trackingEnabled'),
            value: _trackingEnabled,
            onChanged: (bool value) {
              setState(() => _trackingEnabled = value);
            },
          ),
          CheckboxListTile(
            key: const Key('checkbox_safety'),
            title: const Text('Confirm Safety Checklist'),
            value: _safetyChecked,
            onChanged: (bool? value) {
              setState(() => _safetyChecked = value ?? false);
            },
          ),
          const SizedBox(height: 24),

          // --- 4. SLIDER ---
          Text('Calibration', style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          const SizedBox(height: 8),
          Semantics(
            label: 'Aperture Control Slider',
            value: '${_apertureValue.round()} percent',
            child: Slider(
              key: const Key('slider_aperture'),
              value: _apertureValue,
              min: 0,
              max: 100,
              divisions: 10,
              label: _apertureValue.round().toString(),
              onChanged: (double value) {
                setState(() => _apertureValue = value);
              },
            ),
          ),
          const SizedBox(height: 24),

          // --- 5. RADIO ---
          Text(
            'Observation Mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _modeValue,
            onChanged: (int? value) {
              if (value != null) setState(() => _modeValue = value);
            },
            child: Column(
              children: const [
                RadioListTile<int>(
                  key: Key('radio_mode_visual'),
                  title: Text('Visual'),
                  value: 1,
                ),
                RadioListTile<int>(
                  key: Key('radio_mode_radio'),
                  title: Text('Radio'),
                  value: 2,
                ),
                RadioListTile<int>(
                  key: Key('radio_mode_infrared'),
                  title: Text('Infrared'),
                  value: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- 6. STATE INSPECTOR ---
          // A read-only summary of all widget state on this page.
          // After a screenshot, the agent can visually confirm values here.
          // After interactions, the agent can cross-check via evaluate():
          //   evaluate('tapCount.toString()')  → button tap count
          //   evaluate('lastInput')            → observer name field content
          Text(
            'State Inspector',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          const SizedBox(height: 4),
          InfoRow('tapCount', app_globals.tapCount.toString()),
          InfoRow(
            'lastInput',
            app_globals.lastInput.isEmpty
                ? '(empty)'
                : '"${app_globals.lastInput}"',
          ),
          InfoRow('trackingEnabled', _trackingEnabled.toString()),
          InfoRow('safetyChecked', _safetyChecked.toString()),
          InfoRow('apertureValue', _apertureValue.toStringAsFixed(1)),
          InfoRow('modeValue', _modeValue.toString()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
