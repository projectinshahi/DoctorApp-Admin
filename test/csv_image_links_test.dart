import 'package:admin_drapp/services/csv_image_links.dart';
import 'package:flutter_test/flutter_test.dart';

const _header = 'question_order,question_text,question_image_filename,'
    'option_a,option_a_image_url,correct_option';

void main() {
  group('linking a question file to uploaded images', () {
    test('a named file becomes the address it was uploaded to', () {
      final result = linkCsvImages(
        '$_header\n'
        '18,Crush injury,q18_rhabdomyolysis.png,Dialysis,,B\n',
        {'q18_rhabdomyolysis.png': 'https://res.cloudinary.com/x/q18.png'},
      );

      expect(result.linked, 1);
      expect(result.missing, isEmpty);
      expect(result.csv, contains('https://res.cloudinary.com/x/q18.png'));
      expect(result.csv, isNot(contains('q18_rhabdomyolysis.png')));
    });

    test('the name is matched whatever case it was typed in', () {
      final result = linkCsvImages(
        '$_header\n18,Crush injury,Q18_Rhabdo.PNG,Dialysis,,B\n',
        {'q18_rhabdo.png': 'https://host/q18.png'},
      );

      expect(result.linked, 1);
    });

    test('an option image is linked too', () {
      final result = linkCsvImages(
        '$_header\n19,Stone,,Nephrostomy,q19_nephrostomy.png,A\n',
        {'q19_nephrostomy.png': 'https://host/q19.png'},
      );

      expect(result.linked, 1);
      expect(result.csv, contains('https://host/q19.png'));
    });

    test('an address already in the file is left alone', () {
      final result = linkCsvImages(
        '$_header\n18,Crush,https://host/already.png,Dialysis,,B\n',
        {'already.png': 'https://host/wrong.png'},
      );

      expect(result.linked, 0);
      expect(result.csv, contains('https://host/already.png'));
      expect(result.missing, isEmpty);
    });

    test('a name nothing was uploaded under is reported, not guessed at', () {
      final result = linkCsvImages(
        '$_header\n'
        '18,Crush,q18.png,Dialysis,,B\n'
        '19,Stone,q19.png,Nephrostomy,,A\n',
        {'q18.png': 'https://host/q18.png'},
      );

      expect(result.linked, 1);
      expect(result.missing, ['q19.png']);
    });

    test('the same missing name is only reported once', () {
      final result = linkCsvImages(
        '$_header\n'
        '18,Crush,shared.png,Dialysis,,B\n'
        '19,Stone,shared.png,Nephrostomy,,A\n',
        const {},
      );

      expect(result.missing, ['shared.png']);
      expect(result.csv, contains('shared.png'), reason: 'nothing to swap in');
    });

    test('a comma inside a stem survives the rewrite', () {
      final result = linkCsvImages(
        '$_header\n'
        '18,"A 26 year old, previously well, collapses",q18.png,Dialysis,,B\n',
        {'q18.png': 'https://host/q18.png'},
      );

      expect(result.csv,
          contains('"A 26 year old, previously well, collapses"'));
      expect(result.linked, 1);
    });

    test('a header-only file is left as it is', () {
      final result = linkCsvImages('$_header\n', {'q18.png': 'https://host/x'});

      expect(result.linked, 0);
      expect(result.missing, isEmpty);
    });

    test('a file with no image column is left as it is', () {
      final result = linkCsvImages(
        'question_text,option_a,correct_option\nCrush,Dialysis,A\n',
        {'q18.png': 'https://host/x'},
      );

      expect(result.linked, 0);
      expect(result.missing, isEmpty);
    });
  });
}
