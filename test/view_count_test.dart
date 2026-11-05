import 'package:admin_drapp/core/format/view_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('view counts read the way the app shows them', () {
    test('below a thousand is the number itself', () {
      expect(formatViewCount(0), '0');
      expect(formatViewCount(950), '950');
      expect(formatViewCount(999), '999');
    });

    test('thousands carry one decimal, and drop it when it is zero', () {
      expect(formatViewCount(1000), '1k');
      expect(formatViewCount(1200), '1.2k');
      expect(formatViewCount(18400), '18.4k');
      expect(formatViewCount(999499), '999.5k');
    });

    test('millions the same way', () {
      expect(formatViewCount(1200000), '1.2M');
      expect(formatViewCount(2000000), '2M');
    });
  });
}
