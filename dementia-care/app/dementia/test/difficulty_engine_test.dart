import 'package:flutter_test/flutter_test.dart';

import 'package:dementia/features/patients/services/difficulty_engine.dart';

void main() {
  group('DifficultyEngine', () {
    test('starts at the easiest level', () {
      expect(DifficultyEngine().currentLevel, 1);
    });

    test('rises one level per quick correct answer', () {
      final engine = DifficultyEngine();
      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 1,
        responseTimeMs: 2000,
      );
      expect(engine.currentLevel, 2);

      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 2,
        responseTimeMs: 2500,
      );
      expect(engine.currentLevel, 3);
    });

    test('never rises above level 5', () {
      final engine = DifficultyEngine();
      for (var i = 0; i < 10; i++) {
        engine.adaptDifficulty(
          lastAnswerCorrect: true,
          currentStreak: i + 1,
          responseTimeMs: 1500,
        );
      }
      expect(engine.currentLevel, 5);
    });

    test('falls after two misses and never below level 1', () {
      final engine = DifficultyEngine();
      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 1,
        responseTimeMs: 2000,
      );
      expect(engine.currentLevel, 2);

      engine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: 3000,
      );
      expect(engine.currentLevel, 2);

      engine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: 3000,
      );
      expect(engine.currentLevel, 1);

      engine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: 3000,
      );
      engine.adaptDifficulty(
        lastAnswerCorrect: false,
        currentStreak: 0,
        responseTimeMs: 3000,
      );
      expect(engine.currentLevel, 1);
    });

    test('a slow answer counts as a miss', () {
      final engine = DifficultyEngine();
      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 1,
        responseTimeMs: 2000,
      );
      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 2,
        responseTimeMs: 20000,
      );
      expect(engine.currentLevel, 1);
    });

    test('reset returns to level 1', () {
      final engine = DifficultyEngine();
      engine.adaptDifficulty(
        lastAnswerCorrect: true,
        currentStreak: 1,
        responseTimeMs: 1000,
      );
      engine.reset();
      expect(engine.currentLevel, 1);
    });
  });
}
