import 'package:flutter_test/flutter_test.dart';
import 'package:monofin/format.dart';

void main() {
  test('money formatting', () {
    expect(amountText(24580.42), '24,580.42');
    expect(money('\$', 1240), '\$1,240.00');
    expect(money('\$', -64.2, signed: true), '−\$64.20');
    expect(coin(0.41200000), '0.412');
    expect(moneyParts('\$', 24580.42), ('\$24,580', '.42'));
  });
}
