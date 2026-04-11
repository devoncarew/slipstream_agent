import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/slipstream_agent.dart';
import 'package:slipstream_agent/src/extension_support.dart';
import 'dart:developer' as dev;

void main() {
  group('SlipstreamAgent', () {
    testWidgets('registers ping extension', (tester) async {
      // In test mode, kDebugMode is true.
      expect(kDebugMode, isTrue);

      SlipstreamAgent.init();

      // We can't easily call the extension directly from the same isolate in a test
      // without some mocking or using the VM service, but we can verify it doesn't crash
      // and that the initialization logic is idempotent.
      SlipstreamAgent.init();
    });
  });

  group('ExtensionParameters', () {
    test('asInt', () {
      final params = ExtensionParameters({'foo': '123'}, method: 'test');
      expect(params.asInt('foo'), 123);
      expect(params.asInt('bar'), isNull);

      final badParams = ExtensionParameters({'foo': 'abc'}, method: 'test');
      expect(() =>
          badParams.asInt('foo'), throwsA(isA<dev.ServiceExtensionResponse>()));
    });

    test('asIntRequired', () {
      final params = ExtensionParameters({'foo': '123'}, method: 'test');
      expect(params.asIntRequired('foo'), 123);
      expect(() => params.asIntRequired('bar'),
          throwsA(isA<dev.ServiceExtensionResponse>()));
    });

    test('asDouble', () {
      final params = ExtensionParameters({'foo': '123.45'}, method: 'test');
      expect(params.asDouble('foo'), 123.45);
      expect(params.asDouble('bar'), isNull);

      final badParams = ExtensionParameters({'foo': 'abc'}, method: 'test');
      expect(() => badParams.asDouble('foo'),
          throwsA(isA<dev.ServiceExtensionResponse>()));
    });
  });

  group('ServiceDescription', () {
    test('tracking registered extensions', () {
      // Clear or ensure we are starting fresh if possible, but since it's a
      // global list we just check for our expected ones.
      SlipstreamAgent.init();

      final ping = registeredExtensions
          .firstWhere((e) => e.name == 'ext.slipstream.ping');
      expect(ping.description, isNotEmpty);
      expect(ping.returns, isNotEmpty);

      final echo = registeredExtensions
          .firstWhere((e) => e.name == 'ext.slipstream.echo');
      expect(echo.description, contains('Echoes'));
      expect(echo.parameters, hasLength(2));
      expect(echo.parameters[0].name, 'message');
      expect(echo.parameters[0].required, isTrue);
    });
  });
}
