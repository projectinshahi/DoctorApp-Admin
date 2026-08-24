import '../models/question_bank_model.dart';
import '../models/sheet_row_model.dart';
import 'question_bank_service.dart';
import 'subject_topic_service.dart';

/// What a sync did, so the caller can report it rather than guess.
class SyncResult {
  final bool isSuccess;

  /// The database ids the sheet's subject/topic names resolved to. Needed to
  /// build the quiz, which filters by id, not by name.
  final int? subjectId;
  final int? topicId;

  final int created;
  final int alreadyPresent;

  /// Rows the API would have rejected, with the reason. Reported rather than
  /// silently dropped - a question missing from a quiz is invisible otherwise.
  final List<String> skipped;

  final String? errorMessage;

  const SyncResult._({
    required this.isSuccess,
    this.subjectId,
    this.topicId,
    this.created = 0,
    this.alreadyPresent = 0,
    this.skipped = const [],
    this.errorMessage,
  });

  factory SyncResult.success({
    required int subjectId,
    required int topicId,
    required int created,
    required int alreadyPresent,
    required List<String> skipped,
  }) =>
      SyncResult._(
        isSuccess: true,
        subjectId: subjectId,
        topicId: topicId,
        created: created,
        alreadyPresent: alreadyPresent,
        skipped: skipped,
      );

  factory SyncResult.failure(String message) =>
      SyncResult._(isSuccess: false, errorMessage: message);

  int get total => created + alreadyPresent;
}

/// Pushes rows read live from the spreadsheet into the question bank.
///
/// The sheet is the authoring surface and the database is what students read,
/// so something has to carry rows across. This does it for exactly the rows an
/// admin picked, at the moment they save the lesson - no import script, no
/// separate step, and nothing pushed that nobody asked for.
///
/// Order matters and each step feeds the next:
///   1. subject name  -> subjectId   (create if missing)
///   2. topic name    -> topicId     (create if missing, under that subject)
///   3. rows          -> questions   (skip ones already there, and invalid ones)
class SheetQuestionSyncService {
  final _taxonomy = SubjectTopicService();
  final _questions = QuestionBankService();

  /// GET /api/questions defaults to limit=20; the dedupe compares against
  /// everything in the topic, so the biggest page is asked for.
  static const int _existingLimit = 100;

  /// Two rows are the same question when their text matches, ignoring case and
  /// surrounding space. There is no natural key in the sheet, and the API has
  /// no upsert - without this, saving the same lesson twice doubles the bank.
  static String _key(String questionText) =>
      questionText.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The API rejects anything outside these, so a bad row is caught here with
  /// a readable reason instead of arriving as a 400 with no row attached.
  static String? _rejectReason(SheetQuestion row) {
    if (row.questionText.trim().isEmpty) return 'no question text';
    if (row.options.length < 2) return 'fewer than 2 options';
    if (row.options.length > 6) return 'more than 6 options';
    if (row.correctIndex == null) {
      return 'correct_option is ${row.correctOption}, '
          'which is outside its ${row.options.length} options';
    }
    return null;
  }

  static num _marks(String raw, num fallback) =>
      num.tryParse(raw.trim()) ?? fallback;

  Future<SyncResult> sync({
    required String subjectName,
    required String topicName,
    required List<SheetQuestion> rows,
  }) async {
    final subjectId = await _resolveSubject(subjectName);
    if (subjectId == null) {
      return SyncResult.failure('Could not find or create subject "$subjectName".');
    }

    final topicId = await _resolveTopic(subjectId, topicName);
    if (topicId == null) {
      return SyncResult.failure('Could not find or create topic "$topicName".');
    }

    // What the bank already holds for this topic, so re-saving is a no-op
    // rather than a duplicate.
    final existing = await _questions.getQuestions(
      subjectId: subjectId,
      topicId: topicId,
      limit: _existingLimit,
    );
    if (!existing.isSuccess || existing.page == null) {
      return SyncResult.failure(
        existing.errorMessage ?? 'Could not read the existing questions.',
      );
    }
    final seen = {
      for (final q in existing.page!.questions) _key(q.questionText),
    };

    var created = 0;
    var alreadyPresent = 0;
    final skipped = <String>[];

    for (final row in rows) {
      final reason = _rejectReason(row);
      if (reason != null) {
        skipped.add('"${_short(row.questionText)}" - $reason');
        continue;
      }

      if (seen.contains(_key(row.questionText))) {
        alreadyPresent++;
        continue;
      }

      final result = await _questions.createQuestion(
        _toQuestion(row, subjectId: subjectId, topicId: topicId),
      );

      if (result.isSuccess) {
        created++;
        // Guards against the same text appearing twice in one sheet tab.
        seen.add(_key(row.questionText));
      } else {
        skipped.add('"${_short(row.questionText)}" - ${result.errorMessage}');
      }
    }

    return SyncResult.success(
      subjectId: subjectId,
      topicId: topicId,
      created: created,
      alreadyPresent: alreadyPresent,
      skipped: skipped,
    );
  }

  static String _short(String text) {
    final trimmed = text.trim();
    return trimmed.length <= 48 ? trimmed : '${trimmed.substring(0, 45)}...';
  }

  /// A name the API already knows, or a new one. A 409 means another request
  /// created it in between, so the list is re-read rather than treated as an
  /// error.
  Future<int?> _resolveSubject(String name) async {
    final wanted = name.trim().toLowerCase();

    final list = await _taxonomy.getSubjects(isActive: null);
    if (list.isSuccess) {
      for (final s in list.subjects ?? const <Subject>[]) {
        if (s.name.trim().toLowerCase() == wanted) return s.id;
      }
    }

    final created = await _taxonomy.createSubject(name: name.trim());
    if (created.isSuccess && created.subject != null) return created.subject!.id;

    final retry = await _taxonomy.getSubjects(isActive: null);
    if (retry.isSuccess) {
      for (final s in retry.subjects ?? const <Subject>[]) {
        if (s.name.trim().toLowerCase() == wanted) return s.id;
      }
    }
    return null;
  }

  Future<int?> _resolveTopic(int subjectId, String name) async {
    final wanted = name.trim().toLowerCase();

    final list = await _taxonomy.getTopics(subjectId: subjectId, isActive: null);
    if (list.isSuccess) {
      for (final t in list.topics ?? const <Topic>[]) {
        if (t.name.trim().toLowerCase() == wanted) return t.id;
      }
    }

    final created =
        await _taxonomy.createTopic(subjectId: subjectId, name: name.trim());
    if (created.isSuccess && created.topic != null) return created.topic!.id;

    final retry = await _taxonomy.getTopics(subjectId: subjectId, isActive: null);
    if (retry.isSuccess) {
      for (final t in retry.topics ?? const <Topic>[]) {
        if (t.name.trim().toLowerCase() == wanted) return t.id;
      }
    }
    return null;
  }

  /// Sheet row -> create payload.
  ///
  /// The sheet keeps marks as text so it round-trips exactly; the API wants
  /// numbers, and marksIncorrect is genuinely negative.
  Question _toQuestion(
    SheetQuestion row, {
    required int subjectId,
    required int topicId,
  }) {
    return Question(
      id: 0, // server-assigned; toPayload() never sends it
      subjectId: subjectId,
      topicId: topicId,
      questionText: row.questionText.trim(),
      questionImageUrl: row.questionImageUrl,
      difficulty: DifficultyX.fromApiValue(row.difficulty.trim().toLowerCase()),
      marksCorrect: _marks(row.marksCorrect, 1),
      marksIncorrect: _marks(row.marksIncorrect, 0),
      explanation:
          row.explanation.trim().isEmpty ? null : row.explanation.trim(),
      status: QuestionStatus.active,
      tagNames: row.tags,
      options: [
        for (var i = 0; i < row.options.length; i++)
          QuestionOption(
            optionText: row.options[i],
            optionImageUrl:
                i < row.optionImageUrls.length ? row.optionImageUrls[i] : null,
            isCorrect: i == row.correctIndex,
            displayOrder: i,
          ),
      ],
    );
  }
}
