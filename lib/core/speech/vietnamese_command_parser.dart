import 'dart:math';

import 'stt_engine.dart';

/// Intent match candidate with an associated heuristic score.
final class _IntentCandidate {
  const _IntentCandidate({
    required this.action,
    required this.score,
    this.targetObject,
    this.unsupportedObjectName,
  });

  final VoiceAction action;
  final double score;
  final SupportedObject? targetObject;
  final String? unsupportedObjectName;
}

/// Production, offline-capable Vietnamese natural language voice command parser.
///
/// Features:
/// - Unicode NFC normalization, lowercase, punctuation removal, whitespace collapsing.
/// - Diacritic-insensitive matching as a robust fallback.
/// - Conversational filler-word stripping.
/// - Explicit negation and conflict detection (returns [UnknownCommand] safely to prevent execution).
/// - Contextual keyword and pattern combinations.
/// - Controlled Levenshtein fuzzy matching for minor STT spelling mistakes (restricted to >= 5 chars).
/// - Multi-intent scoring with confidence thresholding.
/// - 100% on-device heuristic engine (zero cloud/network dependency).
final class VietnameseCommandParser {
  const VietnameseCommandParser({
    this.confidenceThreshold = 0.50,
    this.ambiguityMargin = 0.15,
  });

  final double confidenceThreshold;
  final double ambiguityMargin;

  // ---------------------------------------------------------------------------
  // Main Parse Entry Point
  // ---------------------------------------------------------------------------

  ParsedCommand parse(String rawTranscript) {
    final normalized = normalize(rawTranscript);
    if (normalized.isEmpty) {
      return const EmptyCommand();
    }

    // 1. Check for explicit negation first (e.g. "đừng đọc", "không tìm ví")
    final negationResult = _checkNegation(normalized, rawTranscript);
    if (negationResult != null) {
      return negationResult;
    }

    // 2. Clean transcript by removing conversational filler words
    final cleanStem = _stripFillers(normalized);
    final noDiacritics = removeDiacritics(cleanStem);

    // 3. Score all possible intent candidates
    final candidates = <_IntentCandidate>[];

    // Candidate A: Stop reading (highest priority if stop keywords present)
    final stopCandidate = _scoreStopReading(cleanStem, noDiacritics);
    if (stopCandidate != null) candidates.add(stopCandidate);

    // Candidate B: Read printed text
    final readCandidate = _scoreReadText(cleanStem, noDiacritics);
    if (readCandidate != null) candidates.add(readCandidate);

    // Candidate C: Detect objects / scene exploration
    final detectCandidate = _scoreDetectObjects(cleanStem, noDiacritics);
    if (detectCandidate != null) candidates.add(detectCandidate);

    // Candidate D: Find specific object
    final findCandidate = _scoreFindObject(cleanStem, noDiacritics);
    if (findCandidate != null) {
      // If user said "tìm kính", return UnsupportedObjectCommand directly
      if (findCandidate.unsupportedObjectName != null) {
        return UnsupportedObjectCommand(
          requestedObjectName: findCandidate.unsupportedObjectName!,
        );
      }
      candidates.add(findCandidate);
    } else {
      // Check if user clearly intended to find an object but didn't specify which one
      if (_isUnclearFindIntent(cleanStem, noDiacritics)) {
        return UnknownCommand(transcript: rawTranscript.trim());
      }
    }

    // 4. Filter candidates by minimum confidence threshold
    final validCandidates =
        candidates.where((c) => c.score >= confidenceThreshold).toList();

    if (validCandidates.isEmpty) {
      return UnknownCommand(transcript: rawTranscript.trim());
    }

    // Sort descending by score
    validCandidates.sort((a, b) => b.score.compareTo(a.score));

    // 5. Ambiguity Check: If top 2 candidates have very close scores, reject safely as UnknownCommand
    if (validCandidates.length > 1) {
      final top = validCandidates[0];
      final runnerUp = validCandidates[1];
      if ((top.score - runnerUp.score).abs() < ambiguityMargin &&
          top.action != runnerUp.action) {
        return UnknownCommand(transcript: rawTranscript.trim());
      }
    }

    final best = validCandidates.first;
    return RecognizedCommand(
      action: best.action,
      targetObject: best.targetObject,
    );
  }

  // ---------------------------------------------------------------------------
  // Negation & Conflict Detection
  // ---------------------------------------------------------------------------

  ParsedCommand? _checkNegation(String text, String rawTranscript) {
    final lower = text;
    final noDia = removeDiacritics(lower);

    // Stop reading expressions: "dừng đọc", "ngừng đọc", "thôi đừng đọc nữa" are StopReading actions!
    if (RegExp(r'\b(thôi\s+đừng\s+đọc|đừng\s+đọc\s+nữa|thôi\s+không\s+đọc|ngừng\s+đọc|ngưng\s+đọc|dừng\s+đọc|dừng\s+đoc|ngừng\s+đoc|ngưng\s+đoc|dừng\s+lại)\b')
            .hasMatch(lower) ||
        RegExp(r'\b(thoi\s+dung\s+doc|dung\s+doc\s+nua|ngung\s+doc|dung\s+doc)\b')
            .hasMatch(noDia)) {
      return const RecognizedCommand(
        action: VoiceAction.stopReading,
      );
    }

    // Explicit negations (refusals): return UnknownCommand so no action is triggered
    if (RegExp(r'\b(không\s+muốn\s+đọc|không\s+đọc)\b').hasMatch(lower) ||
        RegExp(r'\b(khong\s+muon\s+doc|khong\s+doc)\b').hasMatch(noDia)) {
      return UnknownCommand(transcript: rawTranscript.trim());
    }

    // Negated find: "đừng tìm", "không tìm", "thôi không tìm ví"
    if (RegExp(r'\b(đừng\s+tìm|không\s+tìm|thôi\s+không\s+tìm|không\s+muốn\s+tìm)\b')
            .hasMatch(lower) ||
        RegExp(r'\b(dung\s+tim|khong\s+tim|thoi\s+khong\s+tim)\b')
            .hasMatch(noDia)) {
      return UnknownCommand(transcript: rawTranscript.trim());
    }

    // Negated detect: "đừng nhận diện", "không nhận diện nữa"
    if (RegExp(r'\b(đừng\s+nhận\s+diện|không\s+nhận\s+diện|thôi\s+không\s+quét)\b')
            .hasMatch(lower) ||
        RegExp(r'\b(dung\s+nhan\s+dien|khong\s+nhan\s+dien)\b')
            .hasMatch(noDia)) {
      return UnknownCommand(transcript: rawTranscript.trim());
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Intent Scorers
  // ---------------------------------------------------------------------------

  /// 1. Stop Reading
  _IntentCandidate? _scoreStopReading(String text, String noDia) {
    double score = 0.0;

    // Exact or strong phrases
    if (RegExp(r'\b(dừng\s+đọc|dừng\s+đoc|dừng\s+lại|ngừng\s+đọc|ngưng\s+đọc|im\s+lặng|thôi\s+đừng\s+đọc\s+nữa|ngừng\s+nói\s+đi|ngừng\s+nói|ngưng\s+nói|tắt\s+tiếng|dừng\s+nói|im\s+đi|thôi\s+không\s+nghe\s+nữa)\b')
        .hasMatch(text)) {
      score = max(score, 1.0);
    } else if (RegExp(r'\b(dung\s+doc|dung\s+lai|ngung\s+doc|im\s+lang|thoi\s+dung\s+doc\s+nua|ngung\s+noi\s+di|ngung\s+noi|tat\s+tieng)\b')
        .hasMatch(noDia)) {
      score = max(score, 0.90);
    }

    // Single word stop triggers
    if (text == 'dừng' || text == 'thôi' || text == 'ngừng' || text == 'ngưng' || text == 'im') {
      score = max(score, 0.85);
    } else if (noDia == 'dung' || noDia == 'thoi' || noDia == 'ngung') {
      score = max(score, 0.80);
    }

    // Fuzzy check on "dừng đọc"
    if (score < 0.60 && levenshteinDistance(text, 'dừng đọc') <= 1) {
      score = max(score, 0.75);
    }

    return score > 0 ? _IntentCandidate(action: VoiceAction.stopReading, score: score) : null;
  }

  /// 2. Read Printed Text
  _IntentCandidate? _scoreReadText(String text, String noDia) {
    // Exclude repeat reading intents if they ever arise
    if (RegExp(r'\b(đọc\s+lại|lặp\s+lại|nghe\s+lại|nói\s+lại|nhắc\s+lại)\b').hasMatch(text) ||
        RegExp(r'\b(doc\s+lai|lap\s+lai|nghe\s+lai|noi\s+lai|nhac\s+lai)\b').hasMatch(noDia)) {
      return null;
    }

    double score = 0.0;

    // Strong patterns:
    // "đọc văn bản", "đọc chữ", "xem trên này viết gì", "tôi muốn đọc cái này", "đọc nội dung trên hộp"
    if (RegExp(r'\b(đọc\s+văn\s+bản|đọc\s+chữ|quét\s+chữ|quét\s+văn\s+bản|đọc\s+nội\s+dung|đọc\s+giúp\s+tôi|đọc\s+đi)\b').hasMatch(text) ||
        RegExp(r'\bxem\s+.*(viết\s+gì|chữ\s+gì)\b').hasMatch(text) ||
        RegExp(r'\b(trên\s+này|trong\s+này|ở\s+đây)\s+.*viết\s+gì\b').hasMatch(text) ||
        RegExp(r'\bmuốn\s+đọc\b').hasMatch(text) ||
        RegExp(r'\bđọc\s+.*(trên\s+hộp|trên\s+bao\s+bì|tờ\s+giấy|nhãn)\b').hasMatch(text)) {
      score = max(score, 0.95);
    } else if (RegExp(r'\b(doc\s+van\s+ban|doc\s+chu|quet\s+chu|doc\s+noi\s+dung)\b').hasMatch(noDia) ||
        RegExp(r'\bxem\s+.*(viet\s+gi|chu\s+gi)\b').hasMatch(noDia) ||
        RegExp(r'\btren\s+nay\s+.*viet\s+gi\b').hasMatch(noDia) ||
        RegExp(r'\bmuon\s+doc\b').hasMatch(noDia) ||
        RegExp(r'\bdoc\s+.*(tren\s+hop|tren\s+bao\s+bi|to\s+giay)\b').hasMatch(noDia)) {
      score = max(score, 0.85);
    }

    // General read verbs with context
    if (score < 0.70) {
      if (text.startsWith('đọc') || text.endsWith('đọc') || text == 'đọc') {
        score = max(score, 0.75);
      } else if (noDia.startsWith('doc') || noDia == 'doc') {
        score = max(score, 0.70);
      }
    }

    // Fuzzy matching for "đọc văn bản" with minor STT typo (e.g. "đọc văn bạn")
    if (score < 0.60 && (levenshteinDistance(text, 'đọc văn bản') <= 2 || levenshteinDistance(noDia, 'doc van ban') <= 2)) {
      score = max(score, 0.75);
    }

    return score > 0 ? _IntentCandidate(action: VoiceAction.readText, score: score) : null;
  }

  /// 3. Detect Objects / Scene Exploration
  _IntentCandidate? _scoreDetectObjects(String text, String noDia) {
    double score = 0.0;

    // Strong patterns:
    // "nhận diện đồ vật", "trước mặt có gì", "xung quanh tôi có gì", "xem có vật gì phía trước"
    if (RegExp(r'\b(nhận\s+diện\s+đồ\s+vật|nhận\s+diện\s+vật\s+thể|quét\s+đồ\s+vật|quét\s+vật\s+thể|tìm\s+đồ\s+vật|tìm\s+vật\s+thể)\b').hasMatch(text) ||
        RegExp(r'\b(trước\s+(?:mặt|măt)|phía\s+trước|xung\s+quanh\s*(tôi)?)\s+.*(có\s+gì|có\s+vật\s+gì|những\s+gì|chướng\s+ngại\s+vật)\b').hasMatch(text) ||
        RegExp(r'\bxem\s+có\s+(vật|đồ|chướng\s+ngại\s+vật)\s+gì\s+(ở\s+)?(phía\s+trước|trước\s+(?:mặt|măt)|xung\s+quanh)\b').hasMatch(text) ||
        text.contains('quét xung quanh') ||
        text.contains('có cái gì ở đây') ||
        text.contains('nhìn xem trước mặt')) {
      score = max(score, 0.95);
    } else if (RegExp(r'\b(nhan\s+dien\s+do\s+vat|nhan\s+dien\s+vat\s+the|quet\s+do\s+vat|tim\s+do\s+vat)\b').hasMatch(noDia) ||
        RegExp(r'\b(truoc\s+mat|phia\s+truoc|xung\s+quanh)\s+.*(co\s+gi|co\s+vat\s+gi|chuong\s+ngai\s+vat)\b').hasMatch(noDia) ||
        RegExp(r'\bxem\s+co\s+(vat|do|chuong\s+ngai\s+vat)\s+gi\s+phia\s+truoc\b').hasMatch(noDia) ||
        noDia.contains('quet xung quanh') ||
        noDia.contains('co cai gi o day')) {
      score = max(score, 0.85);
    }

    // Direct short commands
    if (text == 'nhận diện' || text == 'quét vật' || text == 'quét') {
      score = max(score, 0.70);
    }

    // Fuzzy matching for "nhận diện đồ vật"
    if (score < 0.60 && levenshteinDistance(text, 'nhận diện đồ vật') <= 2) {
      score = max(score, 0.75);
    }

    return score > 0 ? _IntentCandidate(action: VoiceAction.detectObjects, score: score) : null;
  }

  /// 4. Find Object (with object identification)
  _IntentCandidate? _scoreFindObject(String text, String noDia) {
    // Check if query is finding an object:
    // Format 1: "tìm [object]", "tìm kiếm [object]", "giúp tôi tìm [object]"
    // Format 2: "[object] của tôi đâu", "[object] ở đâu", "[object] đâu rồi"
    final extracted = _extractTargetObject(text, noDia);
    if (extracted == null) return null;

    final (targetObject, unsupportedName, score) = extracted;

    if (unsupportedName != null) {
      return _IntentCandidate(
        action: VoiceAction.findObject,
        score: score,
        unsupportedObjectName: unsupportedName,
      );
    }

    return _IntentCandidate(
      action: VoiceAction.findObject,
      targetObject: targetObject,
      score: score,
    );
  }

  // ---------------------------------------------------------------------------
  // Object Extraction & Mapping
  // ---------------------------------------------------------------------------

  /// Extracts the target object name and maps to [SupportedObject] or unsupported string.
  (SupportedObject?, String?, double)? _extractTargetObject(
    String text,
    String noDia,
  ) {
    String? queryCandidate;
    double baseScore = 0.90;

    // Pattern 1: Where-is questions: "[object] của tôi đâu", "[object] ở đâu", "[object] đâu rồi"
    final whereMatch = RegExp(
      r'^(?:có\s+thấy\s+)?(?:cái\s+|chiếc\s+|chùm\s+|quyển\s+|cuốn\s+|tập\s+)?(.+?)\s+(?:của\s+tôi\s+)?(?:(?:nằm\s+)?ở\s+đâu(?:\s+rồi)?(?:\s+nhỉ)?(?:\s+không)?|đâu\s+rồi|đâu\s+nhỉ|đâu|nằm\s+ở\s+đâu)(?:\s+không)?(?:\s+nhỉ)?$',
    ).firstMatch(text);

    if (whereMatch != null) {
      queryCandidate = whereMatch.group(1)?.trim();
      baseScore = 0.95;
    }

    // Pattern 1 fallback (no diacritics): "[object] cua toi dau"
    if (queryCandidate == null) {
      final whereNoDia = RegExp(
        r'^(?:co\s+thay\s+)?(?:cai\s+|chiec\s+|chum\s+|quyen\s+|cuon\s+|tap\s+)?(.+?)\s+(?:cua\s+toi\s+)?(?:(?:nam\s+)?o\s+dau(?:\s+roi)?(?:\s+nhi)?(?:\s+khong)?|dau\s+roi|dau\s+nhi|dau)(?:\s+khong)?(?:\s+nhi)?$',
      ).firstMatch(noDia);
      if (whereNoDia != null) {
        queryCandidate = whereNoDia.group(1)?.trim();
        baseScore = 0.85;
      }
    }

    // Pattern 2: Find prefixes: "tìm [object]", "tìm giúp [object]", "kiếm [object]"
    if (queryCandidate == null) {
      for (final prefix in _findPrefixes) {
        if (text.startsWith(prefix)) {
          queryCandidate = text.substring(prefix.length).trim();
          baseScore = 0.95;
          break;
        }
      }
    }

    // Pattern 2 fallback (no diacritics): "tim [object]", "kiem [object]"
    if (queryCandidate == null) {
      for (final prefix in _findPrefixesNoDia) {
        if (noDia.startsWith(prefix)) {
          queryCandidate = noDia.substring(prefix.length).trim();
          baseScore = 0.85;
          break;
        }
      }
    }

    // Pattern 3: Embedded "tìm [object]" in sentence (e.g. "giúp tôi tìm cái ví với")
    if (queryCandidate == null) {
      final embedMatch =
          RegExp(r'\b(?:tìm|kiếm)\s+(?:kiếm\s+)?(?:cái\s+|chùm\s+|quyển\s+|cuốn\s+)?([^\.,!?]+)')
              .firstMatch(text);
      if (embedMatch != null) {
        queryCandidate = embedMatch.group(1)?.trim();
        baseScore = 0.90;
      }
    }

    if (queryCandidate == null) return null;

    // Clean up query: strip trailing/leading fluff ("giúp tôi", "với", "hộ tôi", "đi", "nhé", "nào", "của tôi")
    queryCandidate = _stripObjectFluff(queryCandidate);

    if (queryCandidate.isEmpty) {
      return null;
    }

    // 1. Direct match in dictionary (with diacritics or diacritic-insensitive)
    final matchedObj = _matchSupportedObject(queryCandidate);
    if (matchedObj != null) {
      return (matchedObj, null, baseScore);
    }

    // 2. Fuzzy match against supported objects (allowing minor STT typos)
    final fuzzyObj = _fuzzyMatchSupportedObject(queryCandidate);
    if (fuzzyObj != null) {
      return (fuzzyObj, null, baseScore * 0.85);
    }

    // 3. If query is generic like "đồ", "đồ vật", "gì đó", it's an unclear object intent
    if (_genericObjectWords.contains(queryCandidate) ||
        _genericObjectWords.contains(removeDiacritics(queryCandidate))) {
      return null; // Will trigger UnknownCommand
    }

    // 4. Query represents a specific unsupported object (e.g. "mắt kính", "xe máy", "mèo", "tivi")
    return (null, queryCandidate, baseScore);
  }

  bool _isUnclearFindIntent(String text, String noDia) {
    if (text == 'tìm' || text == 'kiếm' || text == 'tìm kiếm' ||
        noDia == 'tim' || noDia == 'kiem' || noDia == 'tim kiem') {
      return true;
    }

    if (RegExp(r'^(tìm|kiếm|tìm kiếm)(\s+(giúp|hộ|cho|giùm)?\s*(tôi)?\s*(với|nhé|nào)?)?$').hasMatch(text) ||
        RegExp(r'^(tim|kiem)(\s+(giup|ho|cho|gium)?\s*(toi)?\s*(voi|nhe|nao)?)?$').hasMatch(noDia)) {
      return true;
    }

    if (RegExp(r'\b(tìm|kiếm)\s+(đồ|vật gì|vật)\b').hasMatch(text) ||
        RegExp(r'\b(tim|kiem)\s+(do|vat gi|vat)\b').hasMatch(noDia)) {
      return true;
    }

    return false;
  }

  SupportedObject? _matchSupportedObject(String query) {
    if (_objectAliases.containsKey(query)) {
      return _objectAliases[query];
    }
    final qNoDia = removeDiacritics(query);
    if (_objectAliasesNoDia.containsKey(qNoDia)) {
      return _objectAliasesNoDia[qNoDia];
    }

    // Exact word or substring containment in aliases
    for (final entry in _objectAliases.entries) {
      if (entry.key == query || query.split(' ').contains(entry.key)) {
        return entry.value;
      }
      if (entry.key.length >= 3 && query.contains(entry.key)) {
        return entry.value;
      }
    }

    // Diacritic-insensitive match
    for (final entry in _objectAliasesNoDia.entries) {
      if (entry.key == qNoDia || qNoDia.split(' ').contains(entry.key)) {
        return entry.value;
      }
      if (entry.key.length >= 3 && qNoDia.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  SupportedObject? _fuzzyMatchSupportedObject(String query) {
    for (final entry in _objectAliases.entries) {
      final key = entry.key;
      final maxDist = key.length >= 6 ? 2 : 1;
      if (key.length >= 5 && levenshteinDistance(query, key) <= maxDist) {
        return entry.value;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helper & Cleaning Methods
  // ---------------------------------------------------------------------------

  String _stripFillers(String input) {
    var text = input;
    // Strip leading conversational fillers
    text = text.replaceAll(
      RegExp(r'^(?:xin\s+|làm\s+ơn\s+|bạn\s+ơi\s+|em\s+ơi\s+|anh\s+ơi\s+|chị\s+ơi\s+|tôi\s+muốn\s+|hãy\s+)'),
      '',
    );
    // Strip trailing conversational fillers
    text = text.replaceAll(
      RegExp(r'(?:\s+cho\s+tôi\s+nghe|\s+cho\s+tôi\s+xem|\s+giúp\s+tôi|\s+hộ\s+tôi|\s+giùm\s+tôi|\s+với\s+nhé|\s+với\s+nha|\s+với|\s+nhé|\s+nào|\s+đi|\s+ạ|\s+ơi)$'),
      '',
    );
    return text.trim();
  }

  String _stripObjectFluff(String query) {
    var res = query.trim();
    // Remove leading articles and polite prefixes repeatedly
    while (true) {
      final updated = res
          .replaceAll(
            RegExp(r'^(?:giúp\s+tôi|hộ\s+tôi|giùm\s+tôi|cho\s+tôi|cái|chiếc|chùm|cuốn|quyển|tập)\s+'),
            '',
          )
          .trim();
      if (updated == res) break;
      res = updated;
    }

    // Remove trailing pronouns/fillers repeatedly: của tôi, cho tôi, giúp tôi, với, nhé, đâu, ở đâu
    while (true) {
      final updated = res
          .replaceAll(
            RegExp(r'(?:^|\s+)(?:của\s+tôi|cho\s+tôi|giúp\s+tôi|hộ\s+tôi|giùm\s+tôi|với|nhé|nào|đâu|ở\s+đâu|đi|ạ)$'),
            '',
          )
          .trim();
      if (updated == res) break;
      res = updated;
    }
    return res.trim();
  }

  /// Normalizes transcript: lowercase, strip punctuation, trim & collapse spaces.
  String normalize(String input) {
    var text = input.toLowerCase().trim();
    text = _normalizeNfc(text);
    text = text
        .replaceAll(RegExp(r'[.,!?:;\-()"]'), ' ')
        .replaceAll("'", ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// Removes Vietnamese diacritics into plain ASCII characters.
  static String removeDiacritics(String input) {
    var str = input;
    const diacritics = {
      'a': r'[àáạảãâầấậẩẫăằắặẳẵ]',
      'A': r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]',
      'e': r'[èéẹẻẽêềếệểễ]',
      'E': r'[ÈÉẸẺẼÊỀẾỆỂỄ]',
      'i': r'[ìíịỉĩ]',
      'I': r'[ÌÍỊỈĨ]',
      'o': r'[òóọỏõôồốộổỗơờớợởỡ]',
      'O': r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]',
      'u': r'[ùúụủũưừứựửữ]',
      'U': r'[ÙÚỤỦŨƯỪỨỰỬỮ]',
      'y': r'[ỳýỵỷỹ]',
      'Y': r'[ỲÝỴỶỸ]',
      'd': r'[đ]',
      'D': r'[Đ]',
    };

    for (final entry in diacritics.entries) {
      str = str.replaceAll(RegExp(entry.value), entry.key);
    }
    return str;
  }

  static String _normalizeNfc(String input) {
    var result = input;
    _decomposedToNfc.forEach((decomposed, nfc) {
      if (result.contains(decomposed)) {
        result = result.replaceAll(decomposed, nfc);
      }
    });
    return result;
  }

  /// Levenshtein edit distance between two strings for controlled fuzzy matching.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1,
          min(prev[j + 1] + 1, prev[j] + cost),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[s2.length];
  }

  // ---------------------------------------------------------------------------
  // Dictionaries & Constants
  // ---------------------------------------------------------------------------

  static const List<String> _findPrefixes = [
    'tìm kiếm ',
    'tìm cho tôi ',
    'tìm giúp tôi ',
    'tìm hộ tôi ',
    'tìm giùm tôi ',
    'giúp tôi tìm ',
    'hộ tôi tìm ',
    'giùm tôi tìm ',
    'cho tôi tìm ',
    'kiếm giúp tôi ',
    'kiếm giùm tôi ',
    'kiếm hộ tôi ',
    'kiếm cho tôi ',
    'tìm ',
    'kiếm ',
  ];

  static const List<String> _findPrefixesNoDia = [
    'tim kiem ',
    'tim cho toi ',
    'tim giup toi ',
    'tim ho toi ',
    'tim gium toi ',
    'giup toi tim ',
    'ho toi tim ',
    'gium toi tim ',
    'cho toi tim ',
    'kiem giup toi ',
    'kiem gium toi ',
    'kiem ho toi ',
    'kiem cho toi ',
    'tim ',
    'kiem ',
  ];

  static const Set<String> _genericObjectWords = {
    'đồ',
    'đồ vật',
    'vật',
    'vật thể',
    'gì đó',
    'cái này',
    'cái kia',
    'do',
    'do vat',
    'vat',
    'vat the',
    'gi do',
    'cai nay',
  };

  static const Map<String, SupportedObject> _objectAliases = {
    // Wallet
    'ví': SupportedObject.wallet,
    'cái ví': SupportedObject.wallet,
    'ví tiền': SupportedObject.wallet,
    'bóp': SupportedObject.wallet,
    'cái bóp': SupportedObject.wallet,
    'bóp tiền': SupportedObject.wallet,

    // Keys
    'chìa khóa': SupportedObject.keys,
    'chìa khoá': SupportedObject.keys,
    'chìa kháo': SupportedObject.keys,
    'cái chìa khóa': SupportedObject.keys,
    'cái chìa khoá': SupportedObject.keys,
    'cái chìa kháo': SupportedObject.keys,
    'chùm chìa khóa': SupportedObject.keys,
    'chùm chìa khoá': SupportedObject.keys,
    'chùm chìa kháo': SupportedObject.keys,
    'khóa': SupportedObject.keys,
    'khoá': SupportedObject.keys,
    'kháo': SupportedObject.keys,

    // Phone
    'điện thoại': SupportedObject.phone,
    'cái điện thoại': SupportedObject.phone,
    'điện thoại di động': SupportedObject.phone,
    'smartphone': SupportedObject.phone,
    'dế': SupportedObject.phone,
    'máy điện thoại': SupportedObject.phone,

    // Bottle
    'chai': SupportedObject.bottle,
    'chai nước': SupportedObject.bottle,
    'bình nước': SupportedObject.bottle,
    'cái chai': SupportedObject.bottle,
    'bình': SupportedObject.bottle,
    'cái bình': SupportedObject.bottle,

    // Cup
    'cốc': SupportedObject.cup,
    'ly': SupportedObject.cup,
    'cái cốc': SupportedObject.cup,
    'cái ly': SupportedObject.cup,
    'tách': SupportedObject.cup,
    'ly nước': SupportedObject.cup,
    'cốc nước': SupportedObject.cup,

    // Book
    'sách': SupportedObject.book,
    'cuốn sách': SupportedObject.book,
    'quyển sách': SupportedObject.book,
    'tập sách': SupportedObject.book,

    // Bag
    'túi': SupportedObject.bag,
    'túi xách': SupportedObject.bag,
    'ba lô': SupportedObject.bag,
    'balo': SupportedObject.bag,
    'cặp': SupportedObject.bag,
    'cặp sách': SupportedObject.bag,

    // Chair
    'ghế': SupportedObject.chair,
    'cái ghế': SupportedObject.chair,

    // Person
    'người': SupportedObject.person,
    'ai đó': SupportedObject.person,
    'con người': SupportedObject.person,
  };

  static final Map<String, SupportedObject> _objectAliasesNoDia = {
    for (final entry in _objectAliases.entries)
      removeDiacritics(entry.key): entry.value,
  };

  static const Map<String, String> _decomposedToNfc = {
    'a\u0306\u0300': 'ằ', 'a\u0306\u0301': 'ắ', 'a\u0306\u0303': 'ẵ', 'a\u0306\u0309': 'ẳ', 'a\u0306\u0323': 'ặ',
    'a\u0302\u0300': 'ầ', 'a\u0302\u0301': 'ấ', 'a\u0302\u0303': 'ẫ', 'a\u0302\u0309': 'ẩ', 'a\u0302\u0323': 'ậ',
    'e\u0302\u0300': 'ề', 'e\u0302\u0301': 'ế', 'e\u0302\u0303': 'ễ', 'e\u0302\u0309': 'ể', 'e\u0302\u0323': 'ệ',
    'o\u0302\u0300': 'ồ', 'o\u0302\u0301': 'ố', 'o\u0302\u0303': 'ỗ', 'o\u0302\u0309': 'ổ', 'o\u0302\u0323': 'ộ',
    'o\u031B\u0300': 'ờ', 'o\u031B\u0301': 'ớ', 'o\u031B\u0303': 'ỡ', 'o\u031B\u0309': 'ở', 'o\u031B\u0323': 'ợ',
    'u\u031B\u0300': 'ừ', 'u\u031B\u0301': 'ứ', 'u\u031B\u0303': 'ữ', 'u\u031B\u0309': 'ử', 'u\u031B\u0323': 'ự',
    'ă\u0300': 'ằ', 'ă\u0301': 'ắ', 'ă\u0303': 'ẵ', 'ă\u0309': 'ẳ', 'ă\u0323': 'ặ',
    'â\u0300': 'ầ', 'â\u0301': 'ấ', 'â\u0303': 'ẫ', 'â\u0309': 'ẩ', 'â\u0323': 'ậ',
    'ê\u0300': 'ề', 'ê\u0301': 'ế', 'ê\u0303': 'ễ', 'ê\u0309': 'ể', 'ê\u0323': 'ệ',
    'ô\u0300': 'ồ', 'ô\u0301': 'ố', 'ô\u0303': 'ỗ', 'ô\u0309': 'ổ', 'ô\u0323': 'ộ',
    'ơ\u0300': 'ờ', 'ơ\u0301': 'ớ', 'ơ\u0303': 'ỡ', 'ơ\u0309': 'ở', 'ơ\u0323': 'ợ',
    'ư\u0300': 'ừ', 'ư\u0301': 'ứ', 'ư\u0303': 'ữ', 'ư\u0309': 'ử', 'ư\u0323': 'ự',
    'a\u0300': 'à', 'a\u0301': 'á', 'a\u0303': 'ã', 'a\u0309': 'ả', 'a\u0323': 'ạ',
    'e\u0300': 'è', 'e\u0301': 'é', 'e\u0303': 'ẽ', 'e\u0309': 'ẻ', 'e\u0323': 'ẹ',
    'i\u0300': 'ì', 'i\u0301': 'í', 'i\u0303': 'ĩ', 'i\u0309': 'ỉ', 'i\u0323': 'ị',
    'o\u0300': 'ò', 'o\u0301': 'ó', 'o\u0303': 'õ', 'o\u0309': 'ỏ', 'o\u0323': 'ọ',
    'u\u0300': 'ù', 'u\u0301': 'ú', 'u\u0303': 'ũ', 'u\u0309': 'ủ', 'u\u0323': 'ụ',
    'y\u0300': 'ỳ', 'y\u0301': 'ý', 'y\u0303': 'ỹ', 'y\u0309': 'ỷ', 'y\u0323': 'ỵ',
    'd\u0311': 'đ', 'd\u0335': 'đ', 'd\u0303': 'đ',
  };
}
