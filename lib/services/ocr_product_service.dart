import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrProductSuggestion {
  const OcrProductSuggestion({
    required this.rawText,
    required this.name,
    required this.category,
    required this.confidence,
    this.expiryDate,
  });

  final String rawText;
  final String name;
  final String category;
  final double confidence;
  final DateTime? expiryDate;
}

class OcrProductService {
  static const List<_ProductKeyword> _keywords = [
    _ProductKeyword(['arla', 'maelk'], 'Arla mælk', 'mejeri', 0.92),
    _ProductKeyword(['arla', 'mælk'], 'Arla mælk', 'mejeri', 0.92),
    _ProductKeyword(['maelk'], 'Mælk', 'mejeri', 0.76),
    _ProductKeyword(['mælk'], 'Mælk', 'mejeri', 0.76),
    _ProductKeyword(['milk'], 'Mælk', 'mejeri', 0.7),
    _ProductKeyword(['yoghurt'], 'Yoghurt', 'mejeri', 0.78),
    _ProductKeyword(['yogurt'], 'Yoghurt', 'mejeri', 0.72),
    _ProductKeyword(['ost'], 'Ost', 'mejeri', 0.76),
    _ProductKeyword(['cheese'], 'Ost', 'mejeri', 0.7),
    _ProductKeyword(['smoer'], 'Smør', 'mejeri', 0.76),
    _ProductKeyword(['smør'], 'Smør', 'mejeri', 0.76),
    _ProductKeyword(['butter'], 'Smør', 'mejeri', 0.7),
    _ProductKeyword(['kylling'], 'Kylling', 'kød', 0.78),
    _ProductKeyword(['chicken'], 'Kylling', 'kød', 0.72),
    _ProductKeyword(['okse'], 'Oksekød', 'kød', 0.74),
    _ProductKeyword(['beef'], 'Oksekød', 'kød', 0.7),
    _ProductKeyword(['fisk'], 'Fisk', 'fisk', 0.74),
    _ProductKeyword(['salmon'], 'Laks', 'fisk', 0.72),
    _ProductKeyword(['laks'], 'Laks', 'fisk', 0.78),
    _ProductKeyword(['æg'], 'Æg', 'æg', 0.74),
    _ProductKeyword(['aeg'], 'Æg', 'æg', 0.74),
    _ProductKeyword(['egg'], 'Æg', 'æg', 0.7),
    _ProductKeyword(['salat'], 'Salat', 'grønt', 0.72),
    _ProductKeyword(['tomat'], 'Tomat', 'grønt', 0.72),
    _ProductKeyword(['agurk'], 'Agurk', 'grønt', 0.72),
    _ProductKeyword(['bread'], 'Brød', 'brød', 0.7),
    _ProductKeyword(['broed'], 'Brød', 'brød', 0.72),
    _ProductKeyword(['brød'], 'Brød', 'brød', 0.72),
  ];

  Future<OcrProductSuggestion> analyzeImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      return analyzeText(recognizedText.text);
    } finally {
      await recognizer.close();
    }
  }

  OcrProductSuggestion analyzeText(String rawText) {
    final normalizedText = _normalize(rawText);
    final keyword = _bestKeyword(normalizedText);

    return OcrProductSuggestion(
      rawText: rawText,
      name: keyword?.name ?? 'Ukendt vare',
      category: keyword?.category ?? 'Ukendt',
      confidence: keyword?.confidence ?? 0,
      expiryDate: _findExpiryDate(rawText),
    );
  }

  _ProductKeyword? _bestKeyword(String normalizedText) {
    for (final keyword in _keywords) {
      final hasAllWords = keyword.words.every(normalizedText.contains);
      if (hasAllWords) {
        return keyword;
      }
    }
    return null;
  }

  DateTime? _findExpiryDate(String rawText) {
    final candidates = <DateTime>[];
    final normalized = rawText.replaceAll('\n', ' ');

    final dayFirstPattern = RegExp(
      r'\b([0-3]?\d)[./-]([0-1]?\d)[./-]((?:20)?\d{2})\b',
    );
    for (final match in dayFirstPattern.allMatches(normalized)) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final year = _parseYear(match.group(3)!);
      final date = _validDate(year, month, day);
      if (date != null) {
        candidates.add(date);
      }
    }

    final yearFirstPattern = RegExp(
      r'\b(20\d{2})[./-]([0-1]?\d)[./-]([0-3]?\d)\b',
    );
    for (final match in yearFirstPattern.allMatches(normalized)) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      final date = _validDate(year, month, day);
      if (date != null) {
        candidates.add(date);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    final today = DateTime.now();
    final earliestAllowed = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 7));
    final latestAllowed = DateTime(today.year + 3, today.month, today.day);
    final plausible = candidates.where((date) {
      return !date.isBefore(earliestAllowed) && !date.isAfter(latestAllowed);
    }).toList();

    if (plausible.isEmpty) {
      return null;
    }

    plausible.sort();
    return plausible.first;
  }

  int? _parseYear(String value) {
    final year = int.tryParse(value);
    if (year == null) {
      return null;
    }
    if (year < 100) {
      return 2000 + year;
    }
    return year;
  }

  DateTime? _validDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('å', 'aa')
        .replaceAll('ä', 'ae')
        .replaceAll('æ', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ø', 'oe');
  }
}

class _ProductKeyword {
  const _ProductKeyword(this.words, this.name, this.category, this.confidence);

  final List<String> words;
  final String name;
  final String category;
  final double confidence;
}
