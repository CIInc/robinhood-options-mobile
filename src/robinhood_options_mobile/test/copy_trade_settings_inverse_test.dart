import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

void main() {
  group('CopyTradeSettings', () {
    test('should serialize and deserialize inverse field correctly', () {
      final settings = CopyTradeSettings(
        enabled: true,
        inverse: true,
      );

      final json = settings.toJson();
      expect(json['inverse'], true);

      final deserialized = CopyTradeSettings.fromJson(json);
      expect(deserialized.inverse, true);
    });

    test('should default inverse to false if missing', () {
      final json = {
        'enabled': true,
      };

      final deserialized = CopyTradeSettings.fromJson(json);
      expect(deserialized.inverse, false);
    });
  });
}
