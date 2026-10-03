import 'package:csv/csv.dart';

/// The outcome of pointing a question file's image cells at uploaded files.
class CsvImageLinks {
  /// The file, with every name it could place swapped for an address.
  final String csv;

  /// Names the file asks for that nothing has been uploaded under. The server
  /// refuses the whole row for these, so they are worth saying before it does.
  final List<String> missing;

  /// How many cells were rewritten.
  final int linked;

  const CsvImageLinks({
    required this.csv,
    required this.missing,
    required this.linked,
  });
}

/// Points the image columns of [csv] at the files in [uploads].
///
/// A paper names its pictures - `q18_rhabdomyolysis.png` - while the importer
/// wants an address. Rather than make an admin paste 150 Cloudinary links into
/// a spreadsheet, the panel holds the mapping and the file keeps the names it
/// was written with.
///
/// [uploads] is keyed by filename in lower case. A cell that already holds an
/// address is left alone, so a file mixing hosted links with local names comes
/// through with both intact.
///
/// A file that cannot be read as a table comes back untouched: this is a
/// convenience, and it must never be the thing that stops an upload.
CsvImageLinks linkCsvImages(String csv, Map<String, String> uploads) {
  List<List<dynamic>> rows;
  try {
    rows = Csv().decode(csv);
  } catch (_) {
    return CsvImageLinks(csv: csv, missing: const [], linked: 0);
  }
  if (rows.length < 2) {
    return CsvImageLinks(csv: csv, missing: const [], linked: 0);
  }

  // question_image_filename, question_image_url, option_a_image_url ... all
  // carry the same thing under different names, so the column is found by what
  // it says rather than by a fixed list.
  final imageColumns = <int>[
    for (var i = 0; i < rows.first.length; i++)
      if ('${rows.first[i]}'.toLowerCase().contains('image')) i,
  ];
  if (imageColumns.isEmpty) {
    return CsvImageLinks(csv: csv, missing: const [], linked: 0);
  }

  final missing = <String>{};
  var linked = 0;

  for (final row in rows.skip(1)) {
    for (final column in imageColumns) {
      if (column >= row.length) continue;
      final cell = '${row[column] ?? ''}'.trim();
      if (cell.isEmpty ||
          cell.startsWith('http://') ||
          cell.startsWith('https://')) {
        continue;
      }

      final url = uploads[cell.toLowerCase()];
      if (url == null) {
        missing.add(cell);
      } else {
        row[column] = url;
        linked++;
      }
    }
  }

  return CsvImageLinks(
    csv: linked == 0 ? csv : Csv().encode(rows),
    missing: missing.toList()..sort(),
    linked: linked,
  );
}
