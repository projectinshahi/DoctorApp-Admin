import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_drapp/models/chapter_summary_model.dart';
import 'package:admin_drapp/provider/chapter_provider.dart';
import 'package:admin_drapp/services/chapter_services.dart';

/// Stands in for the network so the provider's branches can be driven
/// directly. Records the id it was asked for - the per-course-type routing
/// is the whole point of this provider.
class _FakeChapterService extends ChapterService {
  final ChapterListResult result;
  int? askedFor;

  /// Completed by the test so a load can be held open mid-flight.
  final Completer<void>? gate;

  _FakeChapterService(this.result, {this.gate});

  @override
  Future<ChapterListResult> getChapters({required int courseTypeId}) async {
    askedFor = courseTypeId;
    if (gate != null) await gate!.future;
    return result;
  }
}

void main() {
  test('success populates chapters for the requested course type', () async {
    final chapters = parseChapterSummaries({
      'chapters': [
        {
          'id': 14,
          'courseTypeId': 15,
          'courseId': null,
          'title': 'Internal Medicine',
          'displayOrder': 0,
          'lessons': [
            {'id': 20, 'chapterId': 14, 'title': 'Cardiology Overview', 'type': 'video'},
          ],
        },
      ],
    });
    final fake = _FakeChapterService(ChapterListResult.success(chapters));
    final provider = ChapterListProvider(service: fake);

    expect(provider.loadedOnce, isFalse);

    await provider.load(15);

    expect(fake.askedFor, 15);
    expect(provider.isLoading, isFalse);
    expect(provider.loadedOnce, isTrue);
    expect(provider.errorMessage, isNull);
    expect(provider.chapters.single.title, 'Internal Medicine');
    expect(provider.chapters.single.lessonCount, 1);
  });

  test('failure surfaces the message and leaves the list empty', () async {
    final provider = ChapterListProvider(
      service: _FakeChapterService(ChapterListResult.failure('Session expired.')),
    );

    await provider.load(15);

    expect(provider.isLoading, isFalse);
    expect(provider.loadedOnce, isTrue);
    expect(provider.errorMessage, 'Session expired.');
    expect(provider.chapters, isEmpty);
  });

  test('a load that outlives the provider does not throw', () async {
    // The card disposes its provider when the screen is popped; the request
    // it started still lands afterwards.
    final gate = Completer<void>();
    final provider = ChapterListProvider(
      service: _FakeChapterService(ChapterListResult.success(const []), gate: gate),
    );

    final inFlight = provider.load(15);
    provider.dispose();
    gate.complete();

    await expectLater(inFlight, completes);
  });
}
