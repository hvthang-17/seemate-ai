/// Record of a conservative correction applied to common unambiguous packaging/document labels.
class AppliedCorrection {
  const AppliedCorrection({
    required this.originalSnippet,
    required this.correctedSnippet,
    required this.reason,
  });

  final String originalSnippet;
  final String correctedSnippet;
  final String reason;

  @override
  String toString() => '"$originalSnippet" -> "$correctedSnippet" ($reason)';
}

/// Output of conservative Vietnamese post-processing.
class PostProcessedOcrResult {
  const PostProcessedOcrResult({
    required this.rawText,
    required this.suggestedText,
    required this.corrections,
    required this.warnings,
  });

  /// The raw, unadulterated OCR text (never modified).
  final String rawText;

  /// Safely normalized text with unambiguous common label corrections.
  final String suggestedText;

  /// Detailed list of corrections applied.
  final List<AppliedCorrection> corrections;

  /// Safety warnings regarding sensitive data (medicines, phone numbers, money).
  final List<String> warnings;

  bool get hasModifications => corrections.isNotEmpty;
}

/// Conservative Vietnamese OCR post-processor.
///
/// Rules:
/// - Normalizes Unicode combining characters into precomposed NFC format.
/// - Cleans erratic whitespace and punctuation spacing.
/// - Corrects a small, verified dictionary of unambiguous packaging/document boilerplate headers.
/// - NEVER modifies proper nouns, medical drug names, dosages, phone numbers, prices, or dates.
/// - NEVER invents missing words or guesses uncertain sentences.
final class VietnameseOcrPostProcessor {
  const VietnameseOcrPostProcessor();

  // Dictionary of known boilerplate labels and their frequent OCR misreadings
  static const Map<String, _LabelRule> _labelRules = {
    // 1. "Sản phẩm của" (frequently misread as "Sàn phêm cùa", "San pham cua")
    'sản phẩm của': _LabelRule(
      canonical: 'Sản phẩm của',
      patterns: [
        r'\b[sS][àảaá]n\s+ph[êềèeê]m\s+c[ùùaảa]\b',
        r'\b[sS][aả]n\s+ph[aẩ]m\s+c[uủ]a\b',
      ],
      reason: 'Sửa lỗi dấu nhãn sản phẩm đóng gói',
    ),

    // 2. "CÔNG TY CỔ PHẦN" (frequently misread as "cÒNG TY CỔ PHẨN", "CONG TY CO PHAN")
    'công ty cổ phần': _LabelRule(
      canonical: 'CÔNG TY CỔ PHẦN',
      patterns: [
        r'\b[cC][ÒÔOoòôo][nN][gG]\s+[tT][yY]\s+[cC][ổoôÔỔ][\s\S]{0,1}\s*[pP][hH][ầẩaâ][nN]\b',
        r'\b[cC]ÒNG\s+TY\s+CỔ\s+PHẨN\b',
      ],
      reason: 'Sửa lỗi nhận diện nhãn doanh nghiệp phổ biến',
    ),

    // 3. "Địa chỉ" (frequently misread as "Dịa chi", "Dia chi", "Đia chỉ")
    'địa chỉ': _LabelRule(
      canonical: 'Địa chỉ',
      patterns: [
        r'\b[dDđĐ][iị][aạ]\s+[cch][hH]?[iỉí]\b(?=\s*:)',
        r'\b[dD]ịa\s+chi\b',
      ],
      reason: 'Sửa lỗi dấu tiêu đề địa chỉ liên hệ',
    ),

    // 4. "Hạn sử dụng" (frequently misread as "Hạn sứ dụng", "Han su dung")
    'hạn sử dụng': _LabelRule(
      canonical: 'Hạn sử dụng',
      patterns: [
        r'\b[hH][aạ]n\s+[sS][ứửu][\s\S]{0,1}\s*[dDđĐ][uụ]ng\b',
      ],
      reason: 'Sửa lỗi tiêu đề hạn sử dụng',
    ),

    // 5. "Ngày sản xuất"
    'ngày sản xuất': _LabelRule(
      canonical: 'Ngày sản xuất',
      patterns: [
        r'\b[nN][gG][aà]y\s+[sS][aả]n\s+[xX][uU][ấa]t\b',
      ],
      reason: 'Sửa lỗi tiêu đề ngày sản xuất',
    ),

    // 6. "Xuất xứ"
    'xuất xứ': _LabelRule(
      canonical: 'Xuất xứ',
      patterns: [
        r'\b[xX][uU][ấa]t\s+[xX][uứ][\s\S]{0,1}\b(?=\s*:)',
      ],
      reason: 'Sửa lỗi tiêu đề xuất xứ',
    ),

    // 7. "Thành phần"
    'thành phần': _LabelRule(
      canonical: 'Thành phần',
      patterns: [
        r'\b[tT][hH][aà]nh\s+[pP][hH][aầ]n\b(?=\s*:)',
      ],
      reason: 'Sửa lỗi tiêu đề thành phần',
    ),

    // 8. "Hướng dẫn sử dụng"
    'hướng dẫn sử dụng': _LabelRule(
      canonical: 'Hướng dẫn sử dụng',
      patterns: [
        r'\b[hH][uư][ớơ][nN]g\s+[dDđĐ][aẫ]n\s+[sS][uử][\s\S]{0,1}\s*[dDđĐ][uụ]ng\b',
      ],
      reason: 'Sửa lỗi tiêu đề hướng dẫn sử dụng',
    ),

    // 9. "Khối lượng tịnh"
    'khối lượng tịnh': _LabelRule(
      canonical: 'Khối lượng tịnh',
      patterns: [
        r'\b[kK][hH][ôốo][ií]\s+[lL][uư][ợơ][nN]g\s+[tT][iị]nh\b',
      ],
      reason: 'Sửa lỗi tiêu đề khối lượng tịnh',
    ),
  };

  /// Processes text conservatively.
  PostProcessedOcrResult process(String rawText) {
    if (rawText.trim().isEmpty) {
      return PostProcessedOcrResult(
        rawText: rawText,
        suggestedText: rawText,
        corrections: [],
        warnings: [],
      );
    }

    // 1. Unicode & whitespace normalization
    var text = _normalizeUnicodeNfc(rawText);
    text = _normalizeWhitespaceAndPunctuation(text);

    final applied = <AppliedCorrection>[];
    final warnings = <String>[];

    // Check for critical sensitive patterns to generate protective warnings
    if (RegExp(r'\b(thuốc|kháng sinh|viên|siro|mg|ml|paracetamol|panadol|aspirin|amoxicillin|uống|nhỏ mắt)\b', caseSensitive: false)
        .hasMatch(text)) {
      warnings.add(
        'Thuốc/Liều lượng: Phát hiện thông tin y tế nhạy cảm. Hệ thống bảo toàn số liệu và đơn vị.',
      );
    }

    if (RegExp(r'\b(hsd|nsx|exp|mfg|\d{1,2}[\/\.-]\d{1,2}[\/\.-]\d{2,4})\b', caseSensitive: false)
        .hasMatch(text)) {
      warnings.add(
        'Hạn sử dụng/Ngày tháng: Phát hiện thông tin thời gian hạn dùng. Không tự ý chỉnh sửa.',
      );
    }

    if (RegExp(r'(\d+[\.,]\d+\s*(?:đ|vnd|vnđ|đồng)|\bgiá\b)', caseSensitive: false)
        .hasMatch(text)) {
      warnings.add(
        'Số tiền/Giá cả: Phát hiện mệnh giá tiền tệ. Bảo toàn giá trị tài chính.',
      );
    }

    if (RegExp(r'\b(0\d{9,10}|\(0\d{2,3}\)\d{7,8})\b|\b(đt|sđt|tel|hotline)\b', caseSensitive: false)
        .hasMatch(text)) {
      warnings.add(
        'Số điện thoại: Phát hiện số liên hệ viễn thông. Không làm tròn hoặc thay đổi.',
      );
    }

    // 2. Apply conservative dictionary corrections for unambiguous packaging labels
    for (final rule in _labelRules.values) {
      for (final patternStr in rule.patterns) {
        final regex = RegExp(patternStr, caseSensitive: false);
        final matches = regex.allMatches(text).toList();

        for (final match in matches) {
          final matchedStr = match.group(0);
          if (matchedStr != null && matchedStr != rule.canonical) {
            applied.add(
              AppliedCorrection(
                originalSnippet: matchedStr,
                correctedSnippet: rule.canonical,
                reason: rule.reason,
              ),
            );
            text = text.replaceRange(match.start, match.end, rule.canonical);
          }
        }
      }
    }

    return PostProcessedOcrResult(
      rawText: rawText,
      suggestedText: text,
      corrections: applied,
      warnings: warnings,
    );
  }

  String _normalizeWhitespaceAndPunctuation(String input) {
    var text = input;
    // Fix spacing before colon/semicolon: e.g. "Địa chỉ :" -> "Địa chỉ:"
    text = text.replaceAllMapped(RegExp(r'\s+([:;])(?=\s|$)'), (m) => m.group(1)!);
    // Normalize consecutive spaces into a single space
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    // Remove blank lines greater than 2
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  String _normalizeUnicodeNfc(String input) {
    var result = input;
    _decomposedToNfc.forEach((decomposed, nfc) {
      if (result.contains(decomposed)) {
        result = result.replaceAll(decomposed, nfc);
      }
    });
    return result;
  }

  static const Map<String, String> _decomposedToNfc = {
    // a with hat/breve and tone marks
    'a\u0306\u0300': 'ằ', 'a\u0300\u0306': 'ằ', 'ă\u0300': 'ằ',
    'a\u0306\u0301': 'ắ', 'a\u0301\u0306': 'ắ', 'ă\u0301': 'ắ',
    'a\u0306\u0303': 'ẵ', 'a\u0303\u0306': 'ẵ', 'ă\u0303': 'ẵ',
    'a\u0306\u0309': 'ẳ', 'a\u0309\u0306': 'ẳ', 'ă\u0309': 'ẳ',
    'a\u0306\u0323': 'ặ', 'a\u0323\u0306': 'ặ', 'ă\u0323': 'ặ',

    'a\u0302\u0300': 'ầ', 'a\u0300\u0302': 'ầ', 'â\u0300': 'ầ',
    'a\u0302\u0301': 'ấ', 'a\u0301\u0302': 'ấ', 'â\u0301': 'ấ',
    'a\u0302\u0303': 'ẫ', 'a\u0303\u0302': 'ẫ', 'â\u0303': 'ẫ',
    'a\u0302\u0309': 'ẩ', 'a\u0309\u0302': 'ẩ', 'â\u0309': 'ẩ',
    'a\u0302\u0323': 'ậ', 'a\u0323\u0302': 'ậ', 'â\u0323': 'ậ',

    'e\u0302\u0300': 'ề', 'e\u0300\u0302': 'ề', 'ê\u0300': 'ề',
    'e\u0302\u0301': 'ế', 'e\u0301\u0302': 'ế', 'ê\u0301': 'ế',
    'e\u0302\u0303': 'ễ', 'e\u0303\u0302': 'ễ', 'ê\u0303': 'ễ',
    'e\u0302\u0309': 'ể', 'e\u0309\u0302': 'ể', 'ê\u0309': 'ể',
    'e\u0302\u0323': 'ệ', 'e\u0323\u0302': 'ệ', 'ê\u0323': 'ệ',

    'o\u0302\u0300': 'ồ', 'o\u0300\u0302': 'ồ', 'ô\u0300': 'ồ',
    'o\u0302\u0301': 'ố', 'o\u0301\u0302': 'ố', 'ô\u0301': 'ố',
    'o\u0302\u0303': 'ỗ', 'o\u0303\u0302': 'ỗ', 'ô\u0303': 'ỗ',
    'o\u0302\u0309': 'ổ', 'o\u0309\u0302': 'ổ', 'ô\u0309': 'ổ',
    'o\u0302\u0323': 'ộ', 'o\u0323\u0302': 'ộ', 'ô\u0323': 'ộ',

    'o\u031B\u0300': 'ờ', 'o\u0300\u031B': 'ờ', 'ơ\u0300': 'ờ',
    'o\u031B\u0301': 'ớ', 'o\u0301\u031B': 'ớ', 'ơ\u0301': 'ớ',
    'o\u031B\u0303': 'ỡ', 'o\u0303\u031B': 'ỡ', 'ơ\u0303': 'ỡ',
    'o\u031B\u0309': 'ở', 'o\u0309\u031B': 'ở', 'ơ\u0309': 'ở',
    'o\u031B\u0323': 'ợ', 'o\u0323\u031B': 'ợ', 'ơ\u0323': 'ợ',

    'u\u031B\u0300': 'ừ', 'u\u0300\u031B': 'ừ', 'ư\u0300': 'ừ',
    'u\u031B\u0301': 'ứ', 'u\u0301\u031B': 'ứ', 'ư\u0301': 'ứ',
    'u\u031B\u0303': 'ữ', 'u\u0303\u031B': 'ữ', 'ư\u0303': 'ữ',
    'u\u031B\u0309': 'ử', 'u\u0309\u031B': 'ử', 'ư\u0309': 'ử',
    'u\u031B\u0323': 'ự', 'u\u0323\u031B': 'ự', 'ư\u0323': 'ự',

    // simple vowels + tone marks
    'a\u0300': 'à', 'a\u0301': 'á', 'a\u0303': 'ã', 'a\u0309': 'ả', 'a\u0323': 'ạ',
    'e\u0300': 'è', 'e\u0301': 'é', 'e\u0303': 'ẽ', 'e\u0309': 'ẻ', 'e\u0323': 'ẹ',
    'i\u0300': 'ì', 'i\u0301': 'í', 'i\u0303': 'ĩ', 'i\u0309': 'ỉ', 'i\u0323': 'ị',
    'o\u0300': 'ò', 'o\u0301': 'ó', 'o\u0303': 'õ', 'o\u0309': 'ỏ', 'o\u0323': 'ọ',
    'u\u0300': 'ù', 'u\u0301': 'ú', 'u\u0303': 'ũ', 'u\u0309': 'ủ', 'u\u0323': 'ụ',
    'y\u0300': 'ỳ', 'y\u0301': 'ý', 'y\u0303': 'ỹ', 'y\u0309': 'ỷ', 'y\u0323': 'ỵ',

    // base vowels + diacritic
    'a\u0306': 'ă', 'a\u0302': 'â', 'e\u0302': 'ê', 'o\u0302': 'ô', 'o\u031B': 'ơ', 'u\u031B': 'ư',
    'd\u0311': 'đ', 'd\u0335': 'đ', 'd\u0303': 'đ',

    // Uppercase
    'A\u0306\u0300': 'Ằ', 'A\u0300\u0306': 'Ằ', 'Ă\u0300': 'Ằ',
    'A\u0306\u0301': 'Ắ', 'A\u0301\u0306': 'Ắ', 'Ă\u0301': 'Ắ',
    'A\u0306\u0303': 'Ẵ', 'A\u0303\u0306': 'Ẵ', 'Ă\u0303': 'Ẵ',
    'A\u0306\u0309': 'Ẳ', 'A\u0309\u0306': 'Ẳ', 'Ă\u0309': 'Ẳ',
    'A\u0306\u0323': 'Ặ', 'A\u0323\u0306': 'Ặ', 'Ă\u0323': 'Ặ',

    'A\u0302\u0300': 'Ầ', 'A\u0300\u0302': 'Ầ', 'Â\u0300': 'Ầ',
    'A\u0302\u0301': 'Ấ', 'A\u0301\u0302': 'Ấ', 'Â\u0301': 'Ấ',
    'A\u0302\u0303': 'Ẫ', 'A\u0303\u0302': 'Ẫ', 'Â\u0303': 'Ẫ',
    'A\u0302\u0309': 'Ẩ', 'A\u0309\u0302': 'Ẩ', 'Â\u0309': 'Ẩ',
    'A\u0302\u0323': 'Ậ', 'A\u0323\u0302': 'Ậ', 'Â\u0323': 'Ậ',

    'E\u0302\u0300': 'Ề', 'E\u0300\u0302': 'Ề', 'Ê\u0300': 'Ề',
    'E\u0302\u0301': 'Ế', 'E\u0301\u0302': 'Ế', 'Ê\u0301': 'Ế',
    'E\u0302\u0303': 'Ễ', 'E\u0303\u0302': 'Ễ', 'Ê\u0303': 'Ễ',
    'E\u0302\u0309': 'Ể', 'E\u0309\u0302': 'Ể', 'Ê\u0309': 'Ể',
    'E\u0302\u0323': 'Ệ', 'E\u0323\u0302': 'Ệ', 'Ê\u0323': 'Ệ',

    'O\u0302\u0300': 'Ồ', 'O\u0300\u0302': 'Ồ', 'Ô\u0300': 'Ồ',
    'O\u0302\u0301': 'Ố', 'O\u0301\u0302': 'Ố', 'Ô\u0301': 'Ố',
    'O\u0302\u0303': 'Ỗ', 'O\u0303\u0302': 'Ỗ', 'Ô\u0303': 'Ỗ',
    'O\u0302\u0309': 'Ổ', 'O\u0309\u0302': 'Ổ', 'Ô\u0309': 'Ổ',
    'O\u0302\u0323': 'Ộ', 'O\u0323\u0302': 'Ộ', 'Ô\u0323': 'Ộ',

    'O\u031B\u0300': 'Ờ', 'O\u0300\u031B': 'Ờ', 'Ơ\u0300': 'Ờ',
    'O\u031B\u0301': 'Ớ', 'O\u0301\u031B': 'Ớ', 'Ơ\u0301': 'Ớ',
    'O\u031B\u0303': 'Ỡ', 'O\u0303\u031B': 'Ỡ', 'Ơ\u0303': 'Ỡ',
    'O\u031B\u0309': 'Ở', 'O\u0309\u031B': 'Ở', 'Ơ\u0309': 'Ở',
    'O\u031B\u0323': 'Ợ', 'O\u0323\u031B': 'Ợ', 'Ơ\u0323': 'Ợ',

    'U\u031B\u0300': 'Ừ', 'U\u0300\u031B': 'Ừ', 'Ư\u0300': 'Ừ',
    'U\u031B\u0301': 'Ứ', 'U\u0301\u031B': 'Ứ', 'Ư\u0301': 'Ứ',
    'U\u031B\u0303': 'Ữ', 'U\u0303\u031B': 'Ữ', 'Ư\u0303': 'Ữ',
    'U\u031B\u0309': 'Ử', 'U\u0309\u031B': 'Ử', 'Ư\u0309': 'Ử',
    'U\u031B\u0323': 'Ự', 'U\u0323\u031B': 'Ự', 'Ư\u0323': 'Ự',

    'A\u0300': 'À', 'A\u0301': 'Á', 'A\u0303': 'Ã', 'A\u0309': 'Ả', 'A\u0323': 'Ạ',
    'E\u0300': 'È', 'E\u0301': 'É', 'E\u0303': 'Ẽ', 'E\u0309': 'Ẻ', 'E\u0323': 'Ẹ',
    'I\u0300': 'Ì', 'I\u0301': 'Í', 'I\u0303': 'Ĩ', 'I\u0309': 'Ỉ', 'I\u0323': 'Ị',
    'O\u0300': 'Ò', 'O\u0301': 'Ó', 'O\u0303': 'Õ', 'O\u0309': 'Ỏ', 'O\u0323': 'Ọ',
    'U\u0300': 'Ù', 'U\u0301': 'Ú', 'U\u0303': 'Ũ', 'U\u0309': 'Ủ', 'U\u0323': 'Ụ',
    'Y\u0300': 'Ỳ', 'Y\u0301': 'Ý', 'Y\u0303': 'Ỹ', 'Y\u0309': 'Ỷ', 'Y\u0323': 'Ỵ',

    'A\u0306': 'Ă', 'A\u0302': 'Â', 'E\u0302': 'Ê', 'O\u0302': 'Ô', 'O\u031B': 'Ơ', 'U\u031B': 'Ư',
    'D\u0311': 'Đ', 'D\u0335': 'Đ', 'D\u0303': 'Đ',
  };
}

class _LabelRule {
  const _LabelRule({
    required this.canonical,
    required this.patterns,
    required this.reason,
  });

  final String canonical;
  final List<String> patterns;
  final String reason;
}
