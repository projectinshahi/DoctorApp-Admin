/// The question-bank spreadsheet, read straight from Google as CSV.
///
/// Uses the gviz endpoint rather than "Publish to web": it addresses tabs by
/// *name*, so adding a tab here needs only its title - no publishing step, and
/// no hunting for the numeric gid, which changes if a tab is recreated.
///
/// The sheet must be shared as "Anyone with the link can view". It already is;
/// if that is ever revoked every request here returns an HTML sign-in page,
/// which SheetCsvService reports rather than trying to parse.
class SheetSources {
  /// From the sheet's own URL: docs.google.com/spreadsheets/d/<THIS>/edit
  static const String documentId = '11EfwT9xXH-6ZxMvVFuyxvOvIcXl43r-4UJi3bTjk7j8';

  /// Tab titles, exactly as they appear along the bottom of the sheet.
  /// "READ ME" is deliberately absent - it holds no question rows.
  static const List<String> tabs = [
    'Internal Med - Cardiology',
    'Internal Med - Pulmonology',
    'Internal Med - GI & Hepatology',
    'Internal Med - Nephrology',
    'Internal Med - Neurology',
    'Internal Med - Endocrinology',
    'Internal Med - Hematology',
    'Internal Med - Infectious Dis',
    'Internal Med - Rheumatology',
    'Internal Med - Emergency Care',
    'Gen Surg - GI & Colorectal',
    'Gen Surg - HPB Surgery',
    'Gen Surg - Breast & Endocrine',
    'Gen Surg - Vascular Surgery',
    'Gen Surg - GU Surgery',
    'Gen Surg - Trauma & Emergency',
    'OBGYN - Obstetrics',
    'OBGYN - Gynaecology',
    'Pediatrics - General',
    'Dermatology - General',
    'ENT - General',
    'Ophthalmology - General',
  ];

  /// Subject names, in the order the tabs are listed.
  ///
  /// Derived rather than declared: a tab title IS "<Subject> - <Topic>", so a
  /// second list would only be a chance for the two to disagree.
  static List<String> get subjects {
    final seen = <String>[];
    for (final tab in tabs) {
      final subject = _split(tab).$1;
      if (!seen.contains(subject)) seen.add(subject);
    }
    return seen;
  }

  /// The topics that exist under [subject].
  static List<String> topicsFor(String? subject) => subject == null
      ? const []
      : [
          for (final tab in tabs)
            if (_split(tab).$1 == subject) _split(tab).$2,
        ];

  /// The tab title for a subject + topic, or null when there isn't one.
  static String? tabFor(String? subject, String? topic) {
    if (subject == null || topic == null) return null;
    final tab = '$subject - $topic';
    return tabs.contains(tab) ? tab : null;
  }

  /// Splits on the FIRST " - " only: subjects never contain it, topics might.
  static (String, String) _split(String tab) {
    final at = tab.indexOf(' - ');
    return at < 0 ? (tab, tab) : (tab.substring(0, at), tab.substring(at + 3));
  }

  /// The CSV URL for one tab. Encoded because tab titles contain spaces and
  /// ampersands ("Gen Surg - GI & Colorectal"), which would otherwise cut the
  /// query string short.
  static String csvUrlFor(String tabName) =>
      'https://docs.google.com/spreadsheets/d/$documentId'
      '/gviz/tq?tqx=out:csv&sheet=${Uri.encodeComponent(tabName)}';
}
