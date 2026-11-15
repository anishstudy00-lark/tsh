import 'package:flutter_test/flutter_test.dart';

import 'package:dementia/features/patients/content/story_library.dart';

void main() {
  group('story library', () {
    test('offers at least five stories', () {
      expect(storyLibrary.length, greaterThanOrEqualTo(5));
    });

    test('every story is complete in English and Hindi', () {
      for (final story in storyLibrary) {
        expect(story.id.trim(), isNotEmpty);
        expect(story.level, greaterThanOrEqualTo(1));
        expect(story.titleEn.trim(), isNotEmpty, reason: story.id);
        expect(story.titleHi.trim(), isNotEmpty, reason: story.id);
        expect(story.textEn.trim().length, greaterThan(80), reason: story.id);
        expect(story.textHi.trim().length, greaterThan(80), reason: story.id);
      }
    });

    test('every story has two or three questions with three options', () {
      for (final story in storyLibrary) {
        expect(
          story.questions.length,
          inInclusiveRange(2, 3),
          reason: '${story.id} question count',
        );
        for (final question in story.questions) {
          expect(question.promptEn.trim(), isNotEmpty, reason: story.id);
          expect(question.promptHi.trim(), isNotEmpty, reason: story.id);
          expect(question.options.length, 3, reason: story.id);
          expect(
            question.correctIndex,
            inInclusiveRange(0, 2),
            reason: story.id,
          );
          for (final option in question.options) {
            expect(option.en.trim(), isNotEmpty, reason: story.id);
            expect(option.hi.trim(), isNotEmpty, reason: story.id);
          }
        }
      }
    });

    test('story ids are unique', () {
      final ids = storyLibrary.map((story) => story.id).toSet();
      expect(ids.length, storyLibrary.length);
    });
  });
}
