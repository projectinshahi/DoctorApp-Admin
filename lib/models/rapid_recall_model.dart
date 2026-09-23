// A titled deck of revision cards, filed under a course and narrowed as far
// as the admin wants.

/// One end of the scope chain, as the API nests it on a deck.
///
/// Subjects come back as `name` and everything else as `title`; both are read
/// here so the breadcrumb does not need to know which is which.
class RecallScopeRef {
  final int id;
  final String label;

  const RecallScopeRef({required this.id, required this.label});

  static RecallScopeRef? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as num?)?.toInt();
    if (id == null) return null;
    final label = '${raw['title'] ?? raw['name'] ?? ''}'.trim();
    return RecallScopeRef(id: id, label: label.isEmpty ? '#$id' : label);
  }
}

/// One revision note: an image, some text, or both.
///
/// Named `Card` after the API's `cards` array, which is the wire shape. The
/// panel calls them notes, because that is what an admin is writing.
///
/// **The image is optional.** A note can be text alone, an image alone, or
/// both. The only rule is the server's: a note with nothing in either half is
/// empty, and it is refused.
class RapidRecallCard {
  final int? id;
  final String? imageUrl;
  final String? note;

  /// Kept so a removed card's upload can be deleted. Only ever set for images
  /// uploaded in this session; the API does not return it.
  final String? imagePublicId;

  const RapidRecallCard({this.id, this.imageUrl, this.note, this.imagePublicId});

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasNote => (note ?? '').trim().isNotEmpty;

  /// The one rule: neither an image nor text. The editor drops an empty row
  /// on save rather than sending it, and the server refuses one if it arrives.
  bool get isEmpty => !hasImage && !hasNote;

  /// The note's heading, and the text under it.
  ///
  /// **A note row on the wire has ONE text field**, so the title and the
  /// description share it: title, blank line, description. That stays plain
  /// text to anything rendering `note` as-is - the student app shows the
  /// heading as its first line - and it is split back apart here.
  ///
  /// Only the FIRST blank line divides them, so a description with paragraphs
  /// of its own survives. A note with no blank line is all description, which
  /// is what every note written before titles existed is.
  String get noteTitle => _splitNote(note).$1;
  String get noteBody => _splitNote(note).$2;

  static (String, String) _splitNote(String? raw) {
    final text = (raw ?? '').replaceAll('\r\n', '\n');
    final gap = text.indexOf('\n\n');
    if (gap < 0) return ('', text.trim());
    return (text.substring(0, gap).trim(), text.substring(gap + 2).trim());
  }

  /// Joins a heading and its text back into the single `note` field.
  ///
  /// A title written with no description reads back as a description next time
  /// the deck is opened: with one field there is nothing recording which half
  /// it was. A real `title` column on the API would remove that wrinkle.
  static String composeNote(String title, String body) {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty) return b;
    if (b.isEmpty) return t;
    return '$t\n\n$b';
  }

  factory RapidRecallCard.fromJson(Map<String, dynamic> json) => RapidRecallCard(
        id: (json['id'] as num?)?.toInt(),
        imageUrl: _clean(json['imageUrl']),
        note: _clean(json['note']),
      );

  /// `displayOrder` is deliberately absent: it comes from the array index on
  /// PUT, so sending one would be a second source of truth.
  Map<String, dynamic> toJson() => {
        if (hasImage) 'imageUrl': imageUrl!.trim(),
        if (hasNote) 'note': note!.trim(),
      };

  RapidRecallCard copyWith({
    String? imageUrl,
    String? note,
    String? imagePublicId,
    bool clearImage = false,
  }) =>
      RapidRecallCard(
        id: id,
        imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
        note: note ?? this.note,
        imagePublicId:
            clearImage ? null : (imagePublicId ?? this.imagePublicId),
      );
}

class RapidRecall {
  final int id;
  final String title;
  final String? description;

  /// `draft` | `published`. New decks are draft - nothing reaches students
  /// until someone publishes it.
  final String status;

  final int cardCount;

  /// Only [courseId] is ever required. The other three each narrow the deck
  /// and each may be null, so a subject-wide deck is not forced onto forty
  /// lessons.
  final int courseId;
  final int? courseTypeId;
  /// The chapter the deck is filed under - what the form calls a subject.
  final int? chapterId;
  final int? lessonId;

  final RecallScopeRef? course;
  final RecallScopeRef? courseType;
  final RecallScopeRef? chapter;
  final RecallScopeRef? lesson;

  /// One optional PDF or DOC handout for the whole deck.
  final String? noteUrl;
  final String? notePublicId;
  final String? noteFileType;

  /// Populated by GET /:id only. The list endpoint sends [cardCount] instead.
  final List<RapidRecallCard> cards;

  const RapidRecall({
    required this.id,
    required this.title,
    required this.courseId,
    this.description,
    this.status = 'draft',
    this.cardCount = 0,
    this.courseTypeId,
    this.chapterId,
    this.lessonId,
    this.course,
    this.courseType,
    this.chapter,
    this.lesson,
    this.noteUrl,
    this.notePublicId,
    this.noteFileType,
    this.cards = const [],
  });

  bool get isPublished => status.toLowerCase() == 'published';

  bool get hasHandout => (noteUrl ?? '').trim().isNotEmpty;

  /// "GP GULF › DHA › Internal Med › Cardiology", stopping wherever the admin
  /// stopped narrowing. Built from the resolved objects the API nests on the
  /// deck, so no extra lookups are needed to render a row.
  List<String> get scopeTrail => [
        for (final ref in [course, courseType, chapter, lesson])
          if (ref != null) ref.label,
      ];

  String get breadcrumb =>
      scopeTrail.isEmpty ? 'No course' : scopeTrail.join(' › ');

  factory RapidRecall.fromJson(Map<String, dynamic> json) {
    final cards = json['cards'];
    return RapidRecall(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: '${json['title'] ?? ''}',
      description: _clean(json['description']),
      status: '${json['status'] ?? 'draft'}',
      cardCount: (json['cardCount'] as num?)?.toInt() ??
          (cards is List ? cards.length : 0),
      courseId: (json['courseId'] as num?)?.toInt() ??
          (json['course'] is Map
              ? ((json['course']['id'] as num?)?.toInt() ?? 0)
              : 0),
      courseTypeId: (json['courseTypeId'] as num?)?.toInt(),
      chapterId: (json['chapterId'] as num?)?.toInt(),
      lessonId: (json['lessonId'] as num?)?.toInt(),
      course: RecallScopeRef.fromJson(json['course']),
      courseType: RecallScopeRef.fromJson(json['courseType']),
      chapter: RecallScopeRef.fromJson(json['chapter']),
      lesson: RecallScopeRef.fromJson(json['lesson']),
      noteUrl: _clean(json['noteUrl']),
      notePublicId: _clean(json['notePublicId']),
      noteFileType: _clean(json['noteFileType']),
      cards: cards is List
          ? cards
              .whereType<Map<String, dynamic>>()
              .map(RapidRecallCard.fromJson)
              .toList()
          : const [],
    );
  }

  /// The write payload for create and update.
  ///
  /// The three optional scope ids are sent even when null: clearing a chapter
  /// has to reach the server as `null`, and omitting the key would leave the
  /// old value in place.
  Map<String, dynamic> toWritePayload() => {
        'courseId': courseId,
        'courseTypeId': courseTypeId,
        'chapterId': chapterId,
        'lessonId': lessonId,
        'title': title.trim(),
        'description': description?.trim(),
        'noteUrl': noteUrl,
        'notePublicId': notePublicId,
        'noteFileType': noteFileType,
      };
}

String? _clean(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}
