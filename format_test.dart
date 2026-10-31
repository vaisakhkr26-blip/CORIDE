import 'package:coride/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money formatting', () {
    expect(money(1100), '₹1,100');
    expect(money(366.66), '₹366.66');
    expect(money(220), '₹220');
  });

  test('equal share rounds down and matches the server', () {
    expect(equalShare(1100, 2), 550);
    expect(equalShare(1100, 3), 366.66);
    expect(equalShare(1100, 4), 275);
    expect(equalShare(1100, 5), 220);
  });

  test('date helpers', () {
    expect(ymd(DateTime(2026, 11, 5)), '2026-11-05');
    expect(hhmm(8, 5), '08:05');
  });
}
