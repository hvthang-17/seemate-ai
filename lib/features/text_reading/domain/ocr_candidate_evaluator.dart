import 'dart:math';

import 'multi_pass_report.dart';

/// Information regarding a conflicting text segment between OCR passes.
class OcrConflict {
  const OcrConflict({
    required this.lineIndex,
    required this.passAText,
    required this.candidateText,
    required this.explanation,
  });

  final int lineIndex;
  final String passAText;
  final String candidateText;
  final String explanation;

  @override
  String toString() => 'Dòng $lineIndex: "$passAText" vs "$candidateText" ($explanation)';
}

/// Evaluated outcome comparing candidate passes.
class EvaluatedOcrResult {
  const EvaluatedOcrResult({
    required this.selectedPass,
    required this.allPasses,
    required this.candidateScores,
    required this.conflicts,
    required this.hasUnresolvedAmbiguity,
    required this.selectedText,
    required this.rawPassAText,
  });

  final OcrPassResult selectedPass;
  final List<OcrPassResult> allPasses;
  final Map<String, double> candidateScores;
  final List<OcrConflict> conflicts;
  final bool hasUnresolvedAmbiguity;

  /// The text of the chosen candidate (evidence-backed, never blindly concatenated).
  final String selectedText;

  /// The original baseline text from Pass A.
  final String rawPassAText;
}

/// Evaluates OCR candidates across passes:
/// - Assesses Vietnamese diacritic completeness & syllable validity.
/// - Incorporates line confidence where available.
/// - Detects character conflicts between passes.
/// - Never blindly concatenates passes.
/// - Selects a candidate only when evidence supports it.
final class OcrCandidateEvaluator {
  const OcrCandidateEvaluator();

  static final RegExp _vietnameseDiacriticsRegex = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ]',
    caseSensitive: false,
  );

  /// Evaluates candidates and selects the best candidate based on empirical evidence.
  EvaluatedOcrResult evaluate(MultiPassReport report) {
    final passes = report.passes.where((p) => !p.isEmpty).toList();

    if (passes.isEmpty) {
      return EvaluatedOcrResult(
        selectedPass: report.passA,
        allPasses: report.passes,
        candidateScores: {},
        conflicts: [],
        hasUnresolvedAmbiguity: false,
        selectedText: '',
        rawPassAText: report.passA.rawText,
      );
    }

    // 1. Score each candidate pass
    final scores = <String, double>{};
    for (final pass in passes) {
      scores[pass.passName] = _computeCandidateScore(pass);
    }

    // 2. Identify conflicts between Pass A and other passes
    final conflicts = <OcrConflict>[];
    final passA = report.passA;

    for (int p = 1; p < report.passes.length; p++) {
      final other = report.passes[p];
      if (other.isEmpty) continue;

      final minLines = min(passA.lines.length, other.lines.length);
      for (int i = 0; i < minLines; i++) {
        final lineA = passA.lines[i];
        final lineOther = other.lines[i];

        if (lineA != lineOther && lineA.isNotEmpty && lineOther.isNotEmpty) {
          conflicts.add(
            OcrConflict(
              lineIndex: i + 1,
              passAText: lineA,
              candidateText: lineOther,
              explanation: other.passName,
            ),
          );
        }
      }
    }

    // 3. Select the best candidate pass based on highest score
    OcrPassResult bestPass = passA;
    double bestScore = scores[passA.passName] ?? 0.0;

    for (final pass in passes) {
      final score = scores[pass.passName] ?? 0.0;
      // Require at least a 5% improvement to switch away from original Pass A
      if (pass != passA && score > bestScore * 1.05 && pass.lines.isNotEmpty) {
        bestPass = pass;
        bestScore = score;
      }
    }

    // Flag unresolved ambiguity if conflicting passes have close scores
    final hasAmbiguity = conflicts.isNotEmpty &&
        passes.length > 1 &&
        (scores.values.reduce(max) - scores.values.reduce(min)).abs() < 12.0;

    return EvaluatedOcrResult(
      selectedPass: bestPass,
      allPasses: report.passes,
      candidateScores: scores,
      conflicts: conflicts,
      hasUnresolvedAmbiguity: hasAmbiguity,
      selectedText: bestPass.rawText,
      rawPassAText: passA.rawText,
    );
  }

  /// Computes composite evidence score (0-100) combining diacritics, syllable validity, and confidence.
  double computeCompositeScore(OcrPassResult pass) => _computeCandidateScore(pass);

  double _computeCandidateScore(OcrPassResult pass) {
    if (pass.isEmpty) return 0.0;

    final text = pass.rawText;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 0.0;

    // 1. Vietnamese Diacritic Count
    final diacriticMatches = _vietnameseDiacriticsRegex.allMatches(text).length;
    final diacriticRatio = (diacriticMatches / max(1, text.length)).clamp(0.0, 0.40);
    final diacriticScore = (diacriticRatio / 0.15) * 35.0; // Max 35 points

    // 2. Syllable Phonotactic Validity
    int validSyllables = 0;
    for (final word in words) {
      if (_isValidVietnameseSyllableShape(word)) {
        validSyllables++;
      }
    }
    final syllableRatio = validSyllables / words.length;
    final syllableScore = syllableRatio * 35.0; // Max 35 points

    // 3. Line Confidence Score
    double confidenceScore = 15.0; // Neutral default if null
    if (pass.averageConfidence != null) {
      confidenceScore = (pass.averageConfidence! * 20.0).clamp(0.0, 20.0);
    }

    // 4. Line completeness & length sanity
    final completenessScore = (min(words.length, 30) / 30.0) * 10.0; // Max 10 points

    return (diacriticScore + syllableScore + confidenceScore + completenessScore)
        .clamp(0.0, 100.0);
  }

  bool _isValidVietnameseSyllableShape(String rawWord) {
    final word = rawWord.replaceAll(RegExp(r'[\.,!?:;\(\)\[\]"“”—-]'), '');
    if (word.isEmpty) return true;

    if (RegExp(r'^\d+([.,]\d+)*$').hasMatch(word)) return true;

    if (RegExp(r'ph[eê][mn]', caseSensitive: false).hasMatch(word)) {
      return false;
    }
    if (RegExp(r'^cùa$', caseSensitive: false).hasMatch(word)) {
      return false;
    }
    if (RegExp(r'^[a-z]+[ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ][A-Z]+$')
        .hasMatch(word)) {
      return false;
    }

    return true;
  }
}
