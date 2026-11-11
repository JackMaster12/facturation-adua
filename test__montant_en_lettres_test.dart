import 'package:facturation_adua/core/montant_en_lettres.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cas = <int, String>{
    71: 'Soixante et onze',
    80: 'Quatre-vingts',
    81: 'Quatre-vingt-un',
    200: 'Deux cents',
    201: 'Deux cent un',
    1000: 'Mille',
    2000: 'Deux mille',
    80000: 'Quatre-vingt mille',
    1000000: 'Un million',
    254500: 'Deux cent cinquante-quatre mille cinq cents',
    99000: 'Quatre-vingt-dix-neuf mille',
    109000: 'Cent neuf mille',
  };
  cas.forEach((n, attendu) {
    test('$n -> $attendu', () => expect(nombreEnLettres(n), attendu));
  });

  test('unité monétaire', () {
    expect(montantEnLettres(10000), 'Dix mille francs CFA');
  });
}
