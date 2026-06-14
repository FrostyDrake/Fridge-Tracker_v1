import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Model for det forslag OCR-servicen finder i et billede.
class OcrProductSuggestion {
  const OcrProductSuggestion({
    required this.rawText,
    required this.name,
    required this.category,
    required this.confidence,
    required this.reason,
    this.expiryDate,
    this.alternativeNames = const [],
  });

  // Al tekst som OCR fandt i billedet.
  final String rawText;

  // Det bedste forslag til varenavn og kategori.
  final String name;
  final String category;

  // Sikkerhedstal mellem 0 og 1.
  final double confidence;

  // Kort forklaring på hvorfor forslaget blev valgt.
  final String reason;

  // Eventuel udløbsdato fundet direkte i teksten.
  final DateTime? expiryDate;

  // Andre mulige produktlinjer, som brugeren kan vælge imellem.
  final List<String> alternativeNames;
}

// Service der bruger ML Kit OCR til at læse varetekst fra billeder.
class OcrProductService {
  // Kendte produktord der gør OCR-forslaget mere præcist.
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

  // Scanner et billede og analyserer den tekst, der bliver fundet.
  Future<OcrProductSuggestion> analyzeImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      // ML Kit læser tekst fra billedfilen.
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      return analyzeText(recognizedText.text);
    } finally {
      // TextRecognizer skal lukkes, når scanningen er færdig.
      await recognizer.close();
    }
  }

  // Analyserer rå OCR-tekst og laver et produktforslag.
  OcrProductSuggestion analyzeText(String rawText) {
    final normalizedText = _normalize(rawText);
    final keyword = _bestKeyword(normalizedText);
    final rankedLines = _rankProductLines(rawText);
    final fallbackName = rankedLines.isEmpty ? null : rankedLines.first;

    return OcrProductSuggestion(
      rawText: rawText,
      name: keyword?.name ?? fallbackName ?? 'Ukendt vare',
      category: keyword?.category ?? 'Ukendt',
      confidence: keyword?.confidence ?? (fallbackName == null ? 0 : 0.45),
      reason: keyword == null
          ? fallbackName == null
                ? 'OCR fandt tekst, men ingen tydelig produktlinje.'
                : 'Forslag baseret på den mest sandsynlige produktlinje.'
          : 'Forslag baseret på kendte produktord.',
      expiryDate: _findExpiryDate(rawText),
      alternativeNames: rankedLines.take(5).toList(),
    );
  }

  // Finder det første keyword, hvor alle ord findes i OCR-teksten.
  _ProductKeyword? _bestKeyword(String normalizedText) {
    for (final keyword in _keywords) {
      final hasAllWords = keyword.words.every(normalizedText.contains);
      if (hasAllWords) {
        return keyword;
      }
    }
    return null;
  }

  // Prøver at finde en udløbsdato i OCR-teksten.
  DateTime? _findExpiryDate(String rawText) {
    final candidates = <DateTime>[];
    final normalized = rawText.replaceAll('\n', ' ');

    // Matcher datoer som 12-06-2026, 12/06/26 eller 12.06.2026.
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

    // Matcher datoer som 2026-06-12.
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

    // Fjerner datoer der virker for gamle eller alt for langt ude i fremtiden.
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

    // Bruger den tidligste plausible dato.
    plausible.sort();
    return plausible.first;
  }

  // Finder produktlinjer og rangerer dem efter hvor sandsynlige de er.
  List<String> _rankProductLines(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.length >= 3)
        .where((line) => !_isNoiseLine(line))
        .toSet()
        .toList();

    // Højeste score kommer først.
    lines.sort((a, b) => _lineScore(b).compareTo(_lineScore(a)));
    return lines.take(8).toList();
  }

  // Sorterer linjer fra som typisk ikke er produktnavne.
  bool _isNoiseLine(String line) {
    final normalized = _normalize(line);
    final letters = RegExp(r'[a-zA-ZæøåÆØÅ]').allMatches(line).length;
    final digits = RegExp(r'\d').allMatches(line).length;

    // Linjer med næsten ingen bogstaver er sjældent produktnavne.
    if (letters < 2) {
      return true;
    }
    if (digits > letters + 2) {
      return true;
    }
    if (RegExp(
      r'^\d+[.,]?\d*\s?(g|kg|ml|l|kcal|kj|%)$',
      caseSensitive: false,
    ).hasMatch(line.trim())) {
      return true;
    }

    // Kendte støjord fra næringsindhold, holdbarhed og links.
    const noiseWords = [
      'bedst',
      'foer',
      'før',
      'sidste',
      'anvendelse',
      'mindst',
      'holdbar',
      'opbevares',
      'naering',
      'næring',
      'energi',
      'protein',
      'fedt',
      'kulhydrat',
      'sukker',
      'salt',
      'ingrediens',
      'ingredienser',
      'produceret',
      'netto',
      'batch',
      'lot',
      'www',
      'http',
    ];

    return noiseWords.any(normalized.contains);
  }

  // Giver en tekstlinje en score som muligt produktnavn.
  int _lineScore(String line) {
    final normalized = _normalize(line);
    final letters = RegExp(r'[a-zA-ZæøåÆØÅ]').allMatches(line).length;
    final words = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 2)
        .length;

    var score = letters + (words * 4);

    // Produktord får ekstra point.
    const productSignals = [
      'arla',
      'maelk',
      'mælk',
      'yoghurt',
      'ost',
      'smoer',
      'smør',
      'kylling',
      'fisk',
      'laks',
      'salat',
      'tomat',
      'agurk',
      'broed',
      'brød',
      'organic',
      'oekologisk',
      'økologisk',
    ];

    for (final signal in productSignals) {
      if (normalized.contains(signal)) {
        score += 20;
      }
    }

    // Meget lange linjer er ofte beskrivelser, ikke navne.
    if (line.length > 40) {
      score -= line.length - 40;
    }

    return score;
  }

  // Gør to-cifrede årstal til 20xx.
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

  // Tjekker om dag, måned og år faktisk kan danne en rigtig dato.
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

  // Normaliserer tekst, så danske bogstaver kan matches mere stabilt.
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

// Binder OCR-keywords sammen med varenavn, kategori og sikkerhed.
class _ProductKeyword {
  const _ProductKeyword(this.words, this.name, this.category, this.confidence);

  final List<String> words;
  final String name;
  final String category;
  final double confidence;
}
