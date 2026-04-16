import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  group('SlipstreamAgent', () {
    testWidgets('init is idempotent', (tester) async {
      expect(kDebugMode, isTrue);
      SlipstreamAgent.init();
      SlipstreamAgent.init();
    });
  });
}
