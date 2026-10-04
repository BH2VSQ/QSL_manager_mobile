import 'package:flutter_test/flutter_test.dart';
import 'package:qsl_manager_mobile/services/qsl_api.dart';

void main() {
  group('normalizeApiBaseUrl', () {
    test('appends the /api path when missing', () {
      expect(normalizeApiBaseUrl('http://10.0.2.2:7055/api'), 'http://10.0.2.2:7055/api');
      expect(normalizeApiBaseUrl('http://10.0.2.2:7055'), 'http://10.0.2.2:7055/api');
      expect(normalizeApiBaseUrl('10.0.2.2:7055'), 'http://10.0.2.2:7055/api');
    });

    test('remaps the web port 7054 to the API port 7055', () {
      expect(normalizeApiBaseUrl('http://10.0.2.2:7054'), 'http://10.0.2.2:7055/api');
      expect(normalizeApiBaseUrl('http://10.0.2.2:7054/api'), 'http://10.0.2.2:7055/api');
    });

    test('strips a pasted health URL', () {
      expect(normalizeApiBaseUrl('http://10.0.2.2:7055/api/health'), 'http://10.0.2.2:7055/api');
    });

    test('rejects empty input', () {
      expect(() => normalizeApiBaseUrl('   '), throwsFormatException);
    });
  });
}
