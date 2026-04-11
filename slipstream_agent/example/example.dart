import 'package:flutter/material.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  // Initialize the Slipstream agent.
  SlipstreamAgent.init();

  runApp(const SlipstreamExampleApp());
}

class SlipstreamExampleApp extends StatelessWidget {
  const SlipstreamExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Slipstream Agent Example')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('The Slipstream agent is active!'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: null,
                child: Text('Target me with the agent'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
