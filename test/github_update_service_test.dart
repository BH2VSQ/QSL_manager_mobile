import 'package:flutter_test/flutter_test.dart';
import 'package:qsl_manager_mobile/services/github_update_service.dart';

void main() {
  group('GitHub update version helpers', () {
    test('normalizes release tags', () {
      expect(normalizeVersion('v0.2.11'), '0.2.11');
      expect(normalizeVersion('V1.2.3+45'), '1.2.3');
      expect(parseBuildNumber('v1.2.3+45'), 45);
      expect(parseBuildNumber('v1.2.3'), 0);
      expect(normalizeVersion('1.2.3-beta.1'), '1.2.3');
    });

    test('compares semantic numeric versions', () {
      expect(compareVersions('0.2.11', '0.2.10'), greaterThan(0));
      expect(compareVersions('0.2.10', '0.2.10'), 0);
      expect(compareVersions('0.2.9', '0.2.10'), lessThan(0));
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('0.2.10+20', '0.2.10+19'), 0);
    });
  });
}
