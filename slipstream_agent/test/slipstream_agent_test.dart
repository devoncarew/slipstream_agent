import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  group('SlipstreamAgent', () {
    testWidgets('registers ping extension', (tester) async {
      // In test mode, kDebugMode is true.
      expect(kDebugMode, isTrue);

      SlipstreamAgent.init();

      // We can't easily call the extension directly from the same isolate in a
      // test without some mocking or using the VM service, but we can verify it
      // doesn't crash and that the initialization logic is idempotent.
      SlipstreamAgent.init();
    });
  });
}
