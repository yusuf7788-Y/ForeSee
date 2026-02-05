import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/achievement_service.dart';
import '../models/player_inventory.dart';

class WordleGameScreen extends StatefulWidget {
  const WordleGameScreen({super.key});

  @override
  State<WordleGameScreen> createState() => _WordleGameScreenState();
}

class _WordleGameScreenState extends State<WordleGameScreen> {
  final StorageService _storageService = StorageService();
  static const int _maxGuesses = 6;
  static const int _wordLength = 5;

  // Türkçe 5 harfli kelime havuzu (yaygın kelimeler)
  static const List<String> _wordPool = [
    'ADRES',
    'AFYON',
    'AHŞAP',
    'AKTÖR',
    'ALBÜM',
    'ALTIK',
    'AMBER',
    'ANKET',
    'ARENA',
    'ARMUT',
    'ASKER',
    'ATLAS',
    'AVARE',
    'AYRIK',
    'BAHÇE',
    'BALIK',
    'BANKA',
    'BAYAT',
    'BEBEK',
    'BEKAR',
    'BESTE',
    'BEYAZ',
    'BILGI',
    'BIRAK',
    'BIÇAK',
    'BOHÇA',
    'BOMBA',
    'BOYUT',
    'BUKET',
    'BULUT',
    'BURSU',
    'BÜFET',
    'CADDE',
    'CEKET',
    'ÇALAR',
    'ÇANTA',
    'ÇARKL',
    'ÇATIK',
    'ÇAYIR',
    'ÇEKİÇ',
    'ÇELİK',
    'ÇERÇE',
    'ÇEŞİT',
    'ÇIKAR',
    'ÇİZGİ',
    'ÇOĞUL',
    'ÇORAP',
    'ÇÖZÜK',
    'DAMAR',
    'DANS ',
    'DERIN',
    'DIKIM',
    'DOLAP',
    'DOLUM',
    'DONAT',
    'DÖNEM',
    'DÖVME',
    'DURUM',
    'DUVAR',
    'DÜĞME',
    'DÜRÜM',
    'EDEN ',
    'EGEME',
    'EKRAN',
    'EMSAL',
    'ERDEM',
    'ERGEN',
    'ERKEK',
    'ESMER',
    'ETRAF',
    'EVRAK',
    'EZBER',
    'FABRI',
    'FALAN',
    'FARUK',
    'FATOŞ',
    'FELAK',
    'FERDI',
    'FIGÜR',
    'FIKIR',
    'FINAL',
    'FIRIN',
    'FLORA',
    'FORMA',
    'FORUM',
    'FOSIL',
    'FUNDA',
    'FÜZEY',
    'GARAJ',
    'GARIP',
    'GAZLI',
    'GEÇEN',
    'GELIR',
    'GENIŞ',
    'GEREK',
    'GITAR',
    'GİYİM',
    'GOLCÜ',
    'GÖBEK',
    'GÖREV',
    'GÖRÜŞ',
    'GÖZLÜ',
    'GRAFK',
    'GRUBA',
    'GÜÇLÜ',
    'GÜLÜM',
    'GÜMÜŞ',
    'GÜNAH',
    'GÜNEŞ',
    'GÜZEL',
    'HAKIM',
    'HALAT',
    'HALIK',
    'HAMUR',
    'HANIM',
    'HARAP',
    'HASAT',
    'HASTA',
    'HATIR',
    'HAVUZ',
    'HAYAT',
    'HAZIR',
    'HEKİM',
    'HELAL',
    'HESAP',
    'HIZLI',
    'HOROZ',
    'HUDUT',
    'HUZUR',
    'IĞDIR',
    'IHALE',
    'ILICA',
    'IRMAK',
    'ISLAK',
    'IŞLIK',
    'İBRET',
    'İÇKİL',
    'İDARI',
    'İFADE',
    'İHRAC',
    'İKİZL',
    'İLAVE',
    'İLERİ',
    'İLGİN',
    'İMAJI',
    'İNCİR',
    'İNSAN',
    'İPLİK',
    'İRADE',
    'İSKEL',
    'İŞARE',
    'İŞLEM',
    'İTİRA',
    'İZLEK',
    'JETON',
    'JILET',
    'JOKER',
    'KABIN',
    'KABLO',
    'KAÇAK',
    'KADEH',
    'KADIM',
    'KAFES',
    'KAĞIT',
    'KALEM',
    'KALIP',
    'KANAT',
    'KANIT',
    'KARAR',
    'KARŞI',
    'KASIS',
    'KASIT',
    'KATIŞ',
    'KAVAK',
    'KAYAK',
    'KAYIP',
    'KAZAK',
    'KAZAN',
    'KEÇİL',
    'KEMIK',
    'KENAR',
    'KEPEK',
    'KESIM',
    'KEŞIF',
    'KIBRI',
    'KIRIK',
    'KIRMA',
    'KISIM',
    'KITAB',
    'KIYMA',
    'KLIMA',
    'KOBAY',
    'KOMIK',
    'KONUM',
    'KORNA',
    'KORUK',
    'KÖKEN',
    'KÖPEK',
    'KÖRPE',
    'KÖŞEL',
    'KREŞO',
    'KURAL',
    'KURUM',
    'KURUŞ',
    'KUŞAK',
    'KUTUP',
    'KUZEN',
    'KÜÇÜK',
    'KÜREK',
    'LAFIZ',
    'LAHIT',
    'LAHMN',
    'LAMBA',
    'LASER',
    'LATES',
    'LAZIM',
    'LEHIM',
    'LEZIZ',
    'LİDER',
    'LİMAN',
    'LİMON',
    'LİSAN',
    'LİSTE',
    'LOBIK',
    'LOKUM',
    'LÜTUF',
    'MACAR',
    'MACUN',
    'MADDE',
    'MADEN',
    'MAHAL',
    'MAKAS',
    'MALUM',
    'MANGA',
    'MANIK',
    'MARKA',
    'MASAL',
    'MASKE',
    'MASUM',
    'MATEM',
    'MATIK',
    'MEKAN',
    'MELUN',
    'MERAK',
    'MESAJ',
    'METAL',
    'METRO',
    'MEYVE',
    'MINIK',
    'MISIR',
    'MIZAH',
    'MODEL',
    'MODEM',
    'MOTOR',
    'MUCUR',
    'MÜDÜR',
    'MÜHÜR',
    'MÜZIK',
    'NARİN',
    'NASİP',
    'NEHIR',
    'NEŞEL',
    'NİŞAN',
    'NİYET',
    'NOKTA',
    'NOTAM',
    'OBEZI',
    'ODACL',
    'OKUMA',
    'OLGUN',
    'OLMAK',
    'OMLET',
    'ONLAR',
    'ORANI',
    'ORGAN',
    'ORTAM',
    'ORUÇL',
    'OTLAR',
    'OYNAK',
    'ÖBEKI',
    'ÖĞLEN',
    'ÖLÇEK',
    'ÖLÇÜM',
    'ÖNDER',
    'ÖRNEĞ',
    'ÖRTÜK',
    'ÖVGÜL',
    'ÖZGÜL',
    'ÖZLEM',
    'PAKET',
    'PANIK',
    'PANKO',
    'PARÇA',
    'PASTA',
    'PATRON',
    'PAYLA',
    'PAZAR',
    'PELIN',
    'PEMBE',
    'PERİM',
    'PERON',
    'PETEK',
    'PIKAP',
    'PİLOT',
    'PİRİN',
    'PİYAS',
    'PLAKA',
    'PLATO',
    'POKER',
    'POLAT',
    'PRENS',
    'PRESE',
    'PROJE',
    'PROVA',
    'PÜRÜZ',
    'RADAR',
    'RADYO',
    'RAHAT',
    'RAKAM',
    'RALLI',
    'RAMPA',
    'RAPOR',
    'REÇEL',
    'REHIM',
    'RENGI',
    'RESIM',
    'RITIM',
    'ROBOT',
    'ROMAN',
    'RÖNTG',
    'RUTIN',
    'SABIR',
    'SABUN',
    'SAĞIR',
    'SAKAL',
    'SAKLA',
    'SALON',
    'SAMAN',
    'SANAT',
    'SARKI',
    'SATIR',
    'SATIS',
    'SAYFA',
    'SEBEP',
    'SEFER',
    'SEÇIM',
    'SEKER',
    'SEMER',
    'SERIĞ',
    'SERÜV',
    'SEVGI',
    'SEZEN',
    'SIKÇA',
    'SILAH',
    'SIMGE',
    'SINAV',
    'SINIF',
    'SINIR',
    'SİGAR',
    'SİSTE',
    'SIVRI',
    'SİYAH',
    'SOFRA',
    'SOĞUK',
    'SOKAK',
    'SOLUK',
    'SONUÇ',
    'SORUN',
    'SOYAD',
    'SPERM',
    'SPREY',
    'SÜPER',
    'SÜRÜM',
    'ŞAHIT',
    'ŞANSI',
    'ŞARKI',
    'ŞEHIR',
    'ŞEKER',
    'ŞENLI',
    'ŞİDDE',
    'ŞİKAY',
    'ŞİMDI',
    'ŞURUP',
    'ŞÜPHE',
    'TABLO',
    'TAHIL',
    'TAHTA',
    'TAKIM',
    'TALEP',
    'TAMAM',
    'TAMIR',
    'TARAF',
    'TARIH',
    'TARLA',
    'TARZB',
    'TAŞIN',
    'TAVIR',
    'TAVUK',
    'TEBRİ',
    'TEKNE',
    'TEKST',
    'TEMAS',
    'TEMPO',
    'TEORI',
    'TERFI',
    'TESIR',
    'TEYIT',
    'TIBBI',
    'TICRE',
    'TIKIM',
    'TISIR',
    'TOLGA',
    'TOMBI',
    'TOPIK',
    'TOPLU',
    'TOPUK',
    'TÖREN',
    'TRAFİ',
    'TREND',
    'TÜKETİ',
    'TÜRLÜ',
    'UÇUCU',
    'UÇUŞL',
    'UĞRAŞ',
    'ULASI',
    'UMUMI',
    'UMUTL',
    'UŞAKI',
    'UYGUL',
    'UYKUL',
    'UZAKL',
    'UZMAN',
    'ÜÇLÜK',
    'ÜLKEK',
    'ÜNLÜK',
    'ÜRETI',
    'ÜRÜNQ',
    'ÜSLUP',
    'ÜYELK',
    'VAATL',
    'VAGON',
    'VAKIT',
    'VAKUM',
    'VAPUR',
    'VARLI',
    'VASAT',
    'VATAN',
    'VEKİL',
    'VERSE',
    'VİDEO',
    'VİRAJ',
    'VİZITO',
    'VOLTA',
    'VURUŞ',
    'YAKIN',
    'YAKLA',
    'YALAN',
    'YALIN',
    'YANIT',
    'YAPIS',
    'YARAR',
    'YARIK',
    'YARIM',
    'YARIN',
    'YASAK',
    'YASAL',
    'YAŞAM',
    'YAŞLI',
    'YATAK',
    'YATAY',
    'YAZIK',
    'YEDEĞİ',
    'YEMEĞİ',
    'YENİL',
    'YERİN',
    'YETİŞ',
    'YIĞIN',
    'YILDI',
    'YİRMİ',
    'YOĞUN',
    'YOKSA',
    'YOLCU',
    'YORUM',
    'YÖRÜK',
    'YUDUM',
    'YUMRU',
    'YUNUS',
    'YURDU',
    'YÜCEL',
    'YÜKSZ',
    'YÜRÜY',
    'YÜZME',
    'ZAFER',
    'ZAHIR',
    'ZAMAN',
    'ZARAR',
    'ZEKAT',
    'ZEMIN',
    'ZEVKI',
    'ZIHNI',
    'ZINDE',
    'ZINIR',
    'ZORLU',
    'ZÜMRE',
  ];

  // Daha basit ve yaygın kelimeler (oyun için ideal)
  static const List<String> _easyWords = [
    'AYRAN',
    'BAHÇE',
    'BALIK',
    'BEBEK',
    'BEYAZ',
    'BULUT',
    'CADDE',
    'ÇANTA',
    'ÇİLEK',
    'ÇORAP',
    'DAMAR',
    'DUVAR',
    'DÜNYA',
    'ERKEK',
    'ESMER',
    'GARAJ',
    'GAZOZ',
    'GITAR',
    'GÖBEK',
    'GÖMLE',
    'GÜNEŞ',
    'GÜZEL',
    'HALAT',
    'HAMAM',
    'HAMUR',
    'HANIM',
    'HASTA',
    'HATIR',
    'HAVLU',
    'HAVUZ',
    'HAYAT',
    'HAZIR',
    'HELAL',
    'HESAP',
    'HOROZ',
    'HUZUR',
    'INSAN',
    'İÇKİ',
    'İLERİ',
    'KABLO',
    'KADEH',
    'KAFES',
    'KAĞIT',
    'KALEM',
    'KALIP',
    'KANAT',
    'KARAR',
    'KARŞI',
    'KAYAK',
    'KAZAK',
    'KAZAN',
    'KEMIK',
    'KENAR',
    'KEPEK',
    'KIBIR',
    'KIRIK',
    'KISIM',
    'KITAP',
    'KIYMA',
    'KOMIK',
    'KONUM',
    'KÖPEK',
    'KURAL',
    'KURUM',
    'KUZEY',
    'KÜÇÜK',
    'KÜREK',
    'LAMBA',
    'LAZIM',
    'LEZIZ',
    'LIDER',
    'LIMAN',
    'LIMON',
    'LISTE',
    'LOKUM',
    'MACAR',
    'MACUN',
    'MADDE',
    'MADEN',
    'MAKAS',
    'MANGA',
    'MARKA',
    'MASAL',
    'MASKE',
    'MASUM',
    'MEKAN',
    'MERAK',
    'MESAJ',
    'METAL',
    'METRO',
    'MEYVE',
    'MINIK',
    'MISIR',
    'MIZAH',
    'MODEL',
    'MOTOR',
    'MÜDÜR',
    'MÜHÜR',
    'MUZIK',
    'NARIN',
    'NASIP',
    'NEHIR',
    'NIYET',
    'NOKTA',
    'ODACI',
    'OKUMA',
    'OLGUN',
    'OMLET',
    'ONLAR',
    'ORGAN',
    'ORTAM',
    'OYNAK',
    'ÖĞLEN',
    'ÖLÇEK',
    'ÖLÇÜM',
    'ÖNDER',
    'ÖRTÜK',
    'ÖZGÜL',
    'ÖZLEM',
    'PAKET',
    'PANIK',
    'PARÇA',
    'PASTA',
    'PAZAR',
    'PEMBE',
    'PERON',
    'PETEK',
    'PIKAP',
    'PILOT',
    'PLAKA',
    'POKER',
    'PRENS',
    'PROJE',
    'PROVA',
    'RADAR',
    'RADYO',
    'RAHAT',
    'RAKAM',
    'RAMPA',
    'RAPOR',
    'REÇEL',
    'RENGI',
    'RESIM',
    'RITIM',
    'ROBOT',
    'ROMAN',
    'RUTIN',
    'SABIR',
    'SABUN',
    'SAÇMA',
    'SAĞIR',
    'SAKAL',
    'SAKLA',
    'SALON',
    'SAMAN',
    'SANAT',
    'SARKI',
    'SATIR',
    'SATIS',
    'SAYFA',
    'SEBEP',
    'SEFER',
    'SEÇIM',
    'SEKER',
    'SEVGI',
    'SIKCA',
    'SILAH',
    'SIMGE',
    'SINAV',
    'SINIF',
    'SINIR',
    'SIYAH',
    'SOFRA',
    'SOGUK',
    'SOKAK',
    'SOLUK',
    'SONUÇ',
    'SORUN',
    'SOYAD',
    'SUPER',
    'SÜPER',
    'SAHIT',
    'SANSI',
    'SARKI',
    'SEHIR',
    'SEKER',
    'SIMDI',
    'SUPHE',
    'TABLO',
    'TAHIL',
    'TAHTA',
    'TAKIM',
    'TALEP',
    'TAMAM',
    'TAMIR',
    'TARAF',
    'TARIH',
    'TARLA',
    'TASIN',
    'TAVIR',
    'TAVUK',
    'TEKNE',
    'TEMAS',
    'TEMPO',
    'TEORI',
    'TEYIT',
    'TOPLU',
    'TOPUK',
    'TÖREN',
    'TREND',
    'TÜRLÜ',
    'UÇUCU',
    'UGRAS',
    'UMUMI',
    'UMUTL',
    'UYGUL',
    'UYUMA',
    'UZMAN',
    'ÜLKEM',
    'ÜRÜNM',
    'ÜSLUP',
    'VAGON',
    'VAKIT',
    'VAPUR',
    'VARLI',
    'VATAN',
    'VEKIL',
    'VIDEO',
    'VURUŞ',
    'YAKIN',
    'YAKLA',
    'YALAN',
    'YALIN',
    'YANIT',
    'YAPIS',
    'YARAR',
    'YARIK',
    'YARIM',
    'YARIN',
    'YASAK',
    'YASAL',
    'YASAM',
    'YASLI',
    'YATAK',
    'YATAY',
    'YAZIK',
    'YEMEK',
    'YENIL',
    'YERIN',
    'YETIS',
    'YIĞIN',
    'YIRMI',
    'YOĞUN',
    'YOKSA',
    'YOLCU',
    'YORUM',
    'YUDUM',
    'YUMRU',
    'YUNUS',
    'YURDU',
    'YÜKSZ',
    'YÜZME',
    'ZAFER',
    'ZAMAN',
    'ZARAR',
    'ZEMIN',
    'ZEVKI',
    'ZIHNI',
    'ZINDE',
    'ZORLU',
  ];

  final Random _rng = Random();
  late String _targetWord;
  final List<String> _guesses = [];
  String _currentGuess = '';
  bool _gameOver = false;
  bool _won = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _targetWord = _easyWords[_rng.nextInt(_easyWords.length)];
      _guesses.clear();
      _currentGuess = '';
      _gameOver = false;
      _won = false;
      _message = '';
    });
  }

  void _onKeyPressed(String key) {
    if (_gameOver) return;

    HapticFeedback.lightImpact();

    if (key == '⌫') {
      if (_currentGuess.isNotEmpty) {
        setState(() {
          _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        });
      }
    } else if (key == '✓') {
      _submitGuess();
    } else {
      if (_currentGuess.length < _wordLength) {
        setState(() {
          _currentGuess += key;
        });
      }
    }
  }

  void _submitGuess() {
    if (_currentGuess.length != _wordLength) {
      setState(() {
        _message = '5 harfli bir kelime gir';
      });
      return;
    }

    setState(() {
      _guesses.add(_currentGuess);
      _message = '';

      if (_currentGuess == _targetWord) {
        _gameOver = true;
        _won = true;
        _showWinDialog();
      } else if (_guesses.length >= _maxGuesses) {
        _gameOver = true;
        _won = false;
        _showLoseDialog();
      }

      _currentGuess = '';
    });
  }

  void _showWinDialog() async {
    final int coinsEarned =
        50 + (_maxGuesses - _guesses.length) * 20; // Bonus for fewer guesses

    PlayerInventory inventory = await _storageService.loadPlayerInventory();
    final updatedInventory = inventory.copyWith(
      fsCoinBalance: inventory.fsCoinBalance + coinsEarned,
    );
    await _storageService.savePlayerInventory(updatedInventory);

    // Başarım kontrolü
    await AchievementService().onGamePlayed('wordle', won: true);
    await AchievementService().onCoinsEarned(updatedInventory.fsCoinBalance);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tebrikler! 🎉',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${_guesses.length} denemede bildin!\n$coinsEarned FsCoin kazandın!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
              },
              child: const Text('Tekrar oyna'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _showLoseDialog() async {
    // Still give a small consolation prize
    const int coinsEarned = 10;

    PlayerInventory inventory = await _storageService.loadPlayerInventory();
    final updatedInventory = inventory.copyWith(
      fsCoinBalance: inventory.fsCoinBalance + coinsEarned,
    );
    await _storageService.savePlayerInventory(updatedInventory);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF020617),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Maalesef bitti 😢',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Doğru cevap: '),
                    TextSpan(
                      text: _targetWord,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yine de $coinsEarned FsCoin kazandın!',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
              },
              child: const Text('Tekrar oyna'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showExitConfirmation() async {
    if (_guesses.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Çıkmak istediğine emin misin?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'Çıkarsan ilerleme kaybolacak ve FsCoin kazanamayacaksın.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Color _getLetterColor(String letter, int index, String guess) {
    if (_targetWord[index] == letter) {
      return Colors.green; // Doğru yerde
    } else if (_targetWord.contains(letter)) {
      return Colors.amber; // Yanlış yerde
    } else {
      return Colors.grey[800]!; // Kelimede yok
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      iconSize: 20,
                      onPressed: () async {
                        if (await _showExitConfirmation()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wordle Türkçe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '5 harfli kelimeyi tahmin et',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_guesses.length}/$_maxGuesses',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message,
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              // Grid
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_maxGuesses, (rowIndex) {
                        String rowWord = '';
                        bool isCurrentRow =
                            rowIndex == _guesses.length && !_gameOver;

                        if (rowIndex < _guesses.length) {
                          rowWord = _guesses[rowIndex];
                        } else if (isCurrentRow) {
                          rowWord = _currentGuess.padRight(_wordLength);
                        } else {
                          rowWord = ' ' * _wordLength;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_wordLength, (colIndex) {
                              final letter = rowWord.length > colIndex
                                  ? rowWord[colIndex]
                                  : '';
                              final isFilledGuess = rowIndex < _guesses.length;

                              Color bgColor;
                              if (isFilledGuess) {
                                bgColor = _getLetterColor(
                                  letter,
                                  colIndex,
                                  rowWord,
                                );
                              } else if (isCurrentRow &&
                                  letter.trim().isNotEmpty) {
                                bgColor = Colors.white10;
                              } else {
                                bgColor = const Color(0xFF111827);
                              }

                              return AnimatedContainer(
                                duration: Duration(
                                  milliseconds: 200 + colIndex * 50,
                                ),
                                width: 52,
                                height: 52,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isCurrentRow && letter.trim().isNotEmpty
                                        ? Colors.white38
                                        : Colors.white10,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    letter.trim(),
                                    style: TextStyle(
                                      color: isFilledGuess
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              // Keyboard
              _buildKeyboard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    const List<String> row1 = [
      'E',
      'R',
      'T',
      'Y',
      'U',
      'I',
      'O',
      'P',
      'Ğ',
      'Ü',
    ];
    const List<String> row2 = [
      'A',
      'S',
      'D',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'Ş',
      'İ',
    ];
    const List<String> row3 = [
      '✓',
      'Z',
      'C',
      'V',
      'B',
      'N',
      'M',
      'Ö',
      'Ç',
      '⌫',
    ];

    Widget buildRow(List<String> keys) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) {
          final isSpecial = key == '✓' || key == '⌫';
          final isSubmit = key == '✓';

          return Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: isSubmit
                  ? Colors.green
                  : isSpecial
                  ? Colors.grey[700]
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => _onKeyPressed(key),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: isSpecial ? 42 : 30,
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    key,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSpecial ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          buildRow(row1),
          const SizedBox(height: 4),
          buildRow(row2),
          const SizedBox(height: 4),
          buildRow(row3),
        ],
      ),
    );
  }
}
