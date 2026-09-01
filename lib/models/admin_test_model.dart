/// Models for the Test feature.
///
/// A Test is NOT a Quiz. A quiz draws a random subset from the shared question
/// bank and differs per student; a test owns a fixed paper uploaded as CSV that
/// every student sits identically, is server-timed, and freezes once anyone has
/// attempted it. They are modelled separately on purpose - sharing types would
/// let a quiz's filter semantics leak into an exam paper.
library;

/// One admin test row.
///
/// The three flags below drive the whole list UI. They are read straight off
/// the response and never inferred from other fields: the server owns the
/// state machine, and a client-side guess would drift from it.
class AdminTest {
  final int id;
  final int courseId;

  /// The exam type the paper belongs to. A course holds several types
  /// (Prelims, Mains, ...) and a paper is written for exactly one of them, so
  /// this - not [courseId] - is what scopes the list.
  final int? courseTypeId;
  final String? courseTypeTitle;
  final String? courseTitle;

  /// How many students have already sat this paper.
  ///
  /// Delete is refused once this is above zero: questions, images and attempts
  /// all cascade, so deleting an attempted paper erases results students sat
  /// for with nothing to restore them from.
  final int attemptCount;

  final String title;
  final String? description;

  /// Shown to the student before they start. Always editable - it changes
  /// nothing already marked.
  final String? instructions;

  /// Free-form test type, as the PATCH body names it.
  final String? type;

  /// The contract the CSV must match, both on upload and on publish.
  final int totalQuestions;

  /// How many questions are actually stored right now.
  final int questionCount;

  final num marksCorrect;

  /// Zero or negative. A positive value would reward wrong answers.
  final num marksIncorrect;

  final int? durationMinutes;

  /// Visible to students.
  final bool isPublished;

  /// The server says the paper is complete and may be published. Used directly
  /// to gate the button - never publish speculatively and read a 409 as "not
  /// ready".
  final bool readyToPublish;

  /// A student has attempted this paper, so it is frozen for good: their score
  /// must stay meaningful. Permanent - there is no unlock.
  final bool isLocked;

  const AdminTest({
    required this.id,
    required this.courseId,
    this.courseTypeId,
    this.courseTypeTitle,
    this.courseTitle,
    this.attemptCount = 0,
    required this.title,
    this.description,
    this.instructions,
    this.type,
    required this.totalQuestions,
    required this.questionCount,
    this.marksCorrect = 1,
    this.marksIncorrect = 0,
    this.durationMinutes,
    this.isPublished = false,
    this.readyToPublish = false,
    this.isLocked = false,
  });

  factory AdminTest.fromJson(Map<String, dynamic> json) => AdminTest(
    id: json['id'] as int,
    courseId: (json['courseId'] as num?)?.toInt() ?? 0,
    // Sent either flat or nested, depending on whether the row was
    // serialised with its relation included.
    courseTypeId:
        (json['courseTypeId'] as num?)?.toInt() ??
        (json['courseType'] is Map
            ? (json['courseType']['id'] as num?)?.toInt()
            : null),
    courseTypeTitle:
        json['courseTypeTitle'] as String? ??
        (json['courseType'] is Map
            ? json['courseType']['title'] as String?
            : null),
    courseTitle:
        json['courseTitle'] as String? ??
        (json['course'] is Map ? json['course']['title'] as String? : null),
    attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
    title: (json['name'] ?? json['title'] ?? '') as String,
    description: json['description'] as String?,
    instructions: json['instructions'] as String?,
    type: json['type'] as String?,
    totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    marksCorrect: json['marksCorrect'] as num? ?? 1,
    marksIncorrect: json['marksIncorrect'] as num? ?? 0,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    isPublished: json['isPublished'] as bool? ?? false,
    readyToPublish: json['readyToPublish'] as bool? ?? false,
    isLocked: json['isLocked'] as bool? ?? false,
  );

  /// Scoped to one exam type, or open to the whole course.
  ///
  /// Null is a real choice, not a missing value: a paper with no course type
  /// is served to every student on the course.
  bool get isScopedToType => courseTypeId != null;

  String get scopeLabel => courseTypeTitle ?? 'All exam types';

  /// Delete cascades to questions, images AND attempts. Once anyone has sat
  /// the paper a plain delete is refused (409); it takes an explicit
  /// deleteAttempts flag, which is a second, deliberate decision.
  bool get canDelete => attemptCount == 0 && !isLocked;

  // ── The two locks ────────────────────────────────────────────────
  //
  // Both trace to one fact: marksCorrect is stored per answer, at the moment
  // the student answers it. Change it afterwards and a single attempt ends up
  // scored two different ways.

  /// A student has STARTED. Scoring and scope are frozen: duration, marks,
  /// totalQuestions and courseType.
  bool get hasAttempts => attemptCount > 0;

  bool get canEditScoring => !hasAttempts;

  /// A student has SUBMITTED. The paper itself is frozen: questions and
  /// images.
  bool get canEditContent => !isLocked;

  /// Why a control is disabled, for the tooltip. Null when nothing is locked.
  String? get scoringLockReason => canEditScoring
      ? null
      : 'Locked — $attemptCount student attempt'
          '${attemptCount == 1 ? ' has' : 's have'} started. Changing this '
          'would score one attempt two different ways.';

  String? get contentLockReason => canEditContent
      ? null
      : 'Locked — a student has already submitted this paper.';

  /// The create-shell body.
  ///
  /// The test endpoint calls the field `name` (like subjects and topics),
  /// not `title` (like courses and quizzes). Both are sent so the payload
  /// survives the backend settling on either.
  Map<String, dynamic> toCreatePayload() => {
    // Sent even when null: null means "the whole course sees it", which the
    // server treats as a deliberate scope, not an omission.
    'courseTypeId': courseTypeId,
    'name': title,
    'title': title,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    if (instructions != null && instructions!.trim().isNotEmpty)
      'instructions': instructions,
    if (type != null && type!.trim().isNotEmpty) 'type': type,
    'totalQuestions': totalQuestions,
    'marksCorrect': marksCorrect,
    'marksIncorrect': marksIncorrect,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
  };

  /// PATCH body for editing an existing test.
  ///
  /// Only sends what the locks allow. Filtering here rather than at the call
  /// site means no screen can accidentally push a frozen field and take a 409
  /// the admin cannot act on.
  Map<String, dynamic> toUpdatePayload() => {
    // Always editable - neither changes anything already marked, so a typo in
    // the rules of a live paper is fixable without building a second test.
    'name': title,
    if (instructions != null) 'instructions': instructions,
    if (description != null) 'description': description,
    if (canEditScoring) ...{
      if (type != null) 'type': type,
      'totalQuestions': totalQuestions,
      'marksCorrect': marksCorrect,
      'marksIncorrect': marksIncorrect,
      'durationMinutes': durationMinutes,
      'courseTypeId': courseTypeId,
    },
  };

  /// The six fields that freeze the moment a student starts.
  static const lockedFieldLabels = [
    'Exam type',
    'Total questions',
    'Marks per correct answer',
    'Negative marks',
    'Duration',
    'Test type',
  ];

  /// Where this test sits in the wizard. Ordered so the list can branch once
  /// rather than testing three booleans at every call site.
  TestState get state {
    if (isLocked) return TestState.locked;
    if (isPublished) return TestState.published;
    if (readyToPublish) return TestState.ready;
    return TestState.draft;
  }

  /// "148 / 200" - a bare count hides the shortfall, and a percentage hides
  /// how many rows are actually missing.
  String get progressLabel => '$questionCount / $totalQuestions';
}

enum TestState { draft, ready, published, locked }

/// One line the importer refused, or warned about.
class TestUploadIssue {
  /// The physical line number in the uploaded file - what the admin will
  /// search for in their spreadsheet app.
  final int row;
  final String field;
  final String message;

  /// Absent or "error" blocks the import. "warning" did not block it.
  final String? severity;

  const TestUploadIssue({
    required this.row,
    required this.field,
    required this.message,
    this.severity,
  });

  bool get isWarning => severity?.toLowerCase() == 'warning';

  factory TestUploadIssue.fromJson(Map<String, dynamic> json) =>
      TestUploadIssue(
        row: (json['row'] as num?)?.toInt() ?? 0,
        field: (json['field'] ?? '') as String,
        message: (json['message'] ?? '') as String,
        severity: json['severity'] as String?,
      );
}

/// One option on a preview question.
///
/// An option can be text, an image, or both - a diagram-based paper often has
/// four images and no text at all, so an empty [text] is legitimate and must
/// not be treated as a missing option.
class TestPreviewOption {
  final String text;
  final String? imageUrl;

  const TestPreviewOption({required this.text, this.imageUrl});

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  /// Accepts an option as a bare string or as an object, and reads the image
  /// under any of the spellings this backend uses across its endpoints.
  factory TestPreviewOption.from(dynamic raw) {
    if (raw is! Map) {
      return TestPreviewOption(text: raw?.toString() ?? '');
    }
    final image =
        raw['optionImageUrl'] ??
        raw['imageUrl'] ??
        raw['option_image_url'] ??
        raw['image'];
    return TestPreviewOption(
      text: (raw['optionText'] ?? raw['text'] ?? raw['option'] ?? '')
          .toString(),
      imageUrl: _clean(image),
    );
  }
}

/// Blank and whitespace-only URLs become null, so `hasImage` never fires on an
/// empty CSV cell.
String? _clean(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// One question as the preview reports it, answer key included.
class TestPreviewQuestion {
  final int id;
  final String questionText;
  final String? questionImageUrl;
  final List<TestPreviewOption> options;

  /// 'A' | 'B' | 'C' | 'D' as the CSV wrote it.
  final String correctOption;
  final String? explanation;

  /// The part of the paper this question belongs to.
  ///
  /// A section is not a record anywhere - it exists exactly when questions
  /// carry its name, so renaming a part means editing this on its questions.
  final String? section;

  final String? subject;
  final String? topic;

  /// 1..n position. Sending a different one swaps with whatever holds it.
  final int? questionOrder;

  const TestPreviewQuestion({
    required this.id,
    required this.questionText,
    this.questionImageUrl,
    required this.options,
    required this.correctOption,
    this.explanation,
    this.section,
    this.subject,
    this.topic,
    this.questionOrder,
  });

  bool get hasImage => (questionImageUrl ?? '').trim().isNotEmpty;

  /// 0-based index into [options], or null when the letter doesn't address one.
  int? get correctIndex {
    final letter = correctOption.trim().toUpperCase();
    if (letter.isEmpty) return null;
    final index = letter.codeUnitAt(0) - 65; // 'A'
    return index >= 0 && index < options.length ? index : null;
  }

  factory TestPreviewQuestion.fromJson(Map<String, dynamic> json) {
    // Options arrive either as a list or as optionA..optionD columns.
    final raw = json['options'];
    final options = raw is List
        ? raw.map(TestPreviewOption.from).toList()
        : _flatOptions(json);

    return TestPreviewQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      questionText:
          (json['questionText'] ?? json['question_text'] ?? '') as String,
      questionImageUrl: _clean(
        json['questionImageUrl'] ??
            json['question_image_url'] ??
            json['imageUrl'],
      ),
      options: options,
      correctOption: (json['correctOption'] ?? json['correct_option'] ?? '')
          .toString(),
      explanation: (json['explanation'] as String?),
      section: _clean(json['section']),
      subject: _clean(json['subject']),
      topic: _clean(json['topic']),
      questionOrder: (json['questionOrder'] as num?)?.toInt(),
    );
  }

  /// Column-per-option form. The image column is looked up beside its text
  /// column under every spelling seen in this project's sheets and APIs, and a
  /// row with only an image column filled still counts as an option.
  static List<TestPreviewOption> _flatOptions(Map<String, dynamic> json) {
    const letters = ['a', 'b', 'c', 'd', 'e', 'f'];
    final result = <TestPreviewOption>[];

    for (var i = 0; i < letters.length; i++) {
      final upper = letters[i].toUpperCase();
      final text = _clean(json['option$upper'] ?? json['option_${letters[i]}']);
      final image = _clean(
        json['option${upper}ImageUrl'] ??
            json['option_${letters[i]}_image_url'] ??
            json['option${i + 1}ImageUrl'] ??
            json['option${i + 1}_image_url'],
      );

      if (text == null && image == null) continue;
      result.add(TestPreviewOption(text: text ?? '', imageUrl: image));
    }
    return result;
  }
}

/// One part of the paper, derived from the labels on its questions.
class TestSection {
  final String name;
  final int questionCount;
  final int? firstOrder;
  final int? lastOrder;

  /// False when this part's questions are not consecutive - the paper runs
  /// Part A, Part B, then Part A again. Almost always a reorder that went
  /// wrong, and invisible in a flat list.
  final bool contiguous;

  const TestSection({
    required this.name,
    required this.questionCount,
    this.firstOrder,
    this.lastOrder,
    this.contiguous = true,
  });

  factory TestSection.fromJson(Map<String, dynamic> json) => TestSection(
        name: (json['name'] ?? '') as String,
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        firstOrder: (json['firstOrder'] as num?)?.toInt(),
        lastOrder: (json['lastOrder'] as num?)?.toInt(),
        contiguous: json['contiguous'] as bool? ?? true,
      );
}

class TestPreview {
  final AdminTest? test;
  final List<TestPreviewQuestion> questions;

  final List<TestSection> sections;

  /// Questions carrying no section label.
  ///
  /// Only a problem alongside a non-empty [sections]: a paper with no parts at
  /// all is normal, a half-labelled one renders questions outside every part.
  final int unsectionedCount;

  const TestPreview({
    this.test,
    this.questions = const [],
    this.sections = const [],
    this.unsectionedCount = 0,
  });

  bool get isPartlySectioned => sections.isNotEmpty && unsectionedCount > 0;

  /// Existing names, offered as suggestions on the question form.
  List<String> get sectionNames => sections.map((s) => s.name).toList();

  factory TestPreview.fromJson(Map<String, dynamic> json) {
    final testJson = json['test'] is Map<String, dynamic>
        ? json['test'] as Map<String, dynamic>
        : null;
    final rows = json['questions'];
    final sections = json['sections'];

    return TestPreview(
      test: testJson == null ? null : AdminTest.fromJson(testJson),
      questions: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(TestPreviewQuestion.fromJson)
                .toList()
          : const [],
      sections: sections is List
          ? sections
                .whereType<Map<String, dynamic>>()
                .map(TestSection.fromJson)
                .toList()
          : const [],
      unsectionedCount: (json['unsectionedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
