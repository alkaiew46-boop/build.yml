import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TranslateXApp());
}

// ============================================================
// TRANSLATE X
// Offline-first translation
// ============================================================

class TranslateXApp extends StatelessWidget {
  const TranslateXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Translate X',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const TranslateXHome(),
    );
  }
}

// ============================================================
// SUPPORTED LANGUAGES
// ML Kit currently supports 50+ languages.
// ============================================================

class LanguageItem {
  final String name;
  final TranslateLanguage language;

  const LanguageItem(this.name, this.language);
}

const languages = <LanguageItem>[
  LanguageItem('English', TranslateLanguage.english),
  LanguageItem('Hindi', TranslateLanguage.hindi),
  LanguageItem('Urdu', TranslateLanguage.urdu),
  LanguageItem('Tamil', TranslateLanguage.tamil),
  LanguageItem('Telugu', TranslateLanguage.telugu),
  LanguageItem('Bengali', TranslateLanguage.bengali),
  LanguageItem('Marathi', TranslateLanguage.marathi),
  LanguageItem('Gujarati', TranslateLanguage.gujarati),
  LanguageItem('Kannada', TranslateLanguage.kannada),
  LanguageItem('Malayalam', TranslateLanguage.malayalam),
  LanguageItem('Punjabi', TranslateLanguage.punjabi),
  LanguageItem('Arabic', TranslateLanguage.arabic),
  LanguageItem('French', TranslateLanguage.french),
  LanguageItem('German', TranslateLanguage.german),
  LanguageItem('Spanish', TranslateLanguage.spanish),
  LanguageItem('Portuguese', TranslateLanguage.portuguese),
  LanguageItem('Italian', TranslateLanguage.italian),
  LanguageItem('Russian', TranslateLanguage.russian),
  LanguageItem('Japanese', TranslateLanguage.japanese),
  LanguageItem('Korean', TranslateLanguage.korean),
  LanguageItem('Chinese', TranslateLanguage.chinese),
  LanguageItem('Turkish', TranslateLanguage.turkish),
  LanguageItem('Vietnamese', TranslateLanguage.vietnamese),
  LanguageItem('Thai', TranslateLanguage.thai),
  LanguageItem('Indonesian', TranslateLanguage.indonesian),
  LanguageItem('Dutch', TranslateLanguage.dutch),
  LanguageItem('Polish', TranslateLanguage.polish),
  LanguageItem('Romanian', TranslateLanguage.romanian),
  LanguageItem('Czech', TranslateLanguage.czech),
  LanguageItem('Danish', TranslateLanguage.danish),
  LanguageItem('Finnish', TranslateLanguage.finnish),
  LanguageItem('Greek', TranslateLanguage.greek),
  LanguageItem('Hebrew', TranslateLanguage.hebrew),
  LanguageItem('Hungarian', TranslateLanguage.hungarian),
  LanguageItem('Norwegian', TranslateLanguage.norwegian),
  LanguageItem('Slovak', TranslateLanguage.slovak),
  LanguageItem('Swedish', TranslateLanguage.swedish),
  LanguageItem('Ukrainian', TranslateLanguage.ukrainian),
];

// ============================================================
// 30-DAY LOCAL SUBSCRIPTION
// NOTE: production app should verify Google Play subscription.
// ============================================================

class SubscriptionManager {
  static const expiryKey = 'translate_x_expiry';

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();

    final expiryMillis = prefs.getInt(expiryKey);

    if (expiryMillis == null) {
      return false;
    }

    final expiry =
        DateTime.fromMillisecondsSinceEpoch(expiryMillis);

    return DateTime.now().isBefore(expiry);
  }

  static Future<void> activate30Days() async {
    final prefs = await SharedPreferences.getInstance();

    final expiry = DateTime.now().add(
      const Duration(days: 30),
    );

    await prefs.setInt(
      expiryKey,
      expiry.millisecondsSinceEpoch,
    );
  }

  static Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(expiryKey);
  }

  static Future<DateTime?> expiryDate() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getInt(expiryKey);

    if (value == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value);
  }
}

// ============================================================
// OFFLINE TRANSLATION ENGINE
// ============================================================

class OfflineTranslator {
  OnDeviceTranslator? _translator;

  Future<void> prepare(
    TranslateLanguage source,
    TranslateLanguage target,
  ) async {
    await close();

    _translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
  }

  Future<String> translate(String text) async {
    if (_translator == null) {
      throw Exception('Translator not prepared');
    }

    return await _translator!.translateText(text);
  }

  Future<void> close() async {
    _translator?.close();
    _translator = null;
  }
}

// ============================================================
// HOME
// ============================================================

class TranslateXHome extends StatefulWidget {
  const TranslateXHome({super.key});

  @override
  State<TranslateXHome> createState() => _TranslateXHomeState();
}

class _TranslateXHomeState extends State<TranslateXHome> {
  final OfflineTranslator translator = OfflineTranslator();

  LanguageItem source = languages[0]; // English
  LanguageItem target = languages[1]; // Hindi

  final inputController = TextEditingController();

  String result = '';

  bool downloading = false;
  bool translating = false;
  bool premium = false;
  bool bubbleRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final active = await SubscriptionManager.isPremium();

    if (!mounted) return;

    setState(() {
      premium = active;
    });
  }

  // ==========================================================
  // DOWNLOAD LANGUAGE MODELS AUTOMATICALLY
  // ==========================================================

  Future<void> _prepareLanguages() async {
    setState(() {
      downloading = true;
    });

    try {
      final manager = OnDeviceTranslatorModelManager();

      await manager.downloadModel(
        source.language.bcpCode,
      );

      await manager.downloadModel(
        target.language.bcpCode,
      );

      await translator.prepare(
        source.language,
        target.language,
      );
    } finally {
      if (mounted) {
        setState(() {
          downloading = false;
        });
      }
    }
  }

  // ==========================================================
  // OFFLINE TRANSLATION
  // ==========================================================

  Future<void> _translate() async {
    if (!premium) {
      _showPremiumDialog();
      return;
    }

    if (inputController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      translating = true;
    });

    try {
      await _prepareLanguages();

      final translated = await translator.translate(
        inputController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        result = translated;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        result =
            'Language model उपलब्ध नहीं है। पहले इस language को download करें.';
      });
    } finally {
      if (mounted) {
        setState(() {
          translating = false;
        });
      }
    }
  }

  // ==========================================================
  // FLOATING BUBBLE
  // ==========================================================

  Future<void> _startBubble() async {
    if (!premium) {
      _showPremiumDialog();
      return;
    }

    final allowed =
        await FlutterOverlayWindow.isPermissionGranted();

    if (!allowed) {
      await FlutterOverlayWindow.requestPermission();
    }

    final nowAllowed =
        await FlutterOverlayWindow.isPermissionGranted();

    if (!nowAllowed) {
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'Translate X',
      overlayContent: 'Translate X Bubble',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 70,
      width: 70,
      startPosition: const OverlayPosition(300, 300),
    );

    setState(() {
      bubbleRunning = true;
    });
  }

  Future<void> _stopBubble() async {
    await FlutterOverlayWindow.closeOverlay();

    setState(() {
      bubbleRunning = false;
    });
  }

  // ==========================================================
  // PREMIUM DIALOG
  // ==========================================================

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Translate X Premium'),
          content: const Text(
            'Offline Floating Bubble और Offline Translation '
            'चलाने के लिए ₹10/month Premium चाहिए।',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                // DEMO ACTIVATION ONLY.
                // Production में Google Play Billing लगेगा.
                await SubscriptionManager.activate30Days();

                await _loadSubscription();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Premium activated for 30 days',
                      ),
                    ),
                  );
                }
              },
              child: const Text('₹10 / Month'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    translator.close();
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: const Center(
                child: Text(
                  'TX',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Translate X',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                premium ? 'PREMIUM' : '₹10/month',
                style: TextStyle(
                  color: premium
                      ? Colors.greenAccent
                      : Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [

            // ==================================================
            // LANGUAGE DIRECTION
            // ==================================================

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _languageDropdown(
                      'From',
                      source,
                      (value) {
                        if (value == null) return;

                        setState(() {
                          source = value;
                        });
                      },
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 28,
                    ),
                  ),

                  Expanded(
                    child: _languageDropdown(
                      'To',
                      target,
                      (value) {
                        if (value == null) return;

                        setState(() {
                          target = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // INPUT
            // ==================================================

            TextField(
              controller: inputController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'English text यहाँ लिखें...',
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // TRANSLATE BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed:
                    translating ? null : _translate,
                icon: const Icon(
                  Icons.translate,
                ),
                label: Text(
                  downloading
                      ? 'Language model डाउनलोड हो रहा है...'
                      : translating
                          ? 'Translating...'
                          : 'Translate Offline',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // RESULT
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Text(
                result.isEmpty
                    ? 'Translation यहाँ दिखाई देगा'
                    : result,
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // FLOATING BUBBLE
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: bubbleRunning
                    ? _stopBubble
                    : _startBubble,
                icon: Icon(
                  bubbleRunning
                      ? Icons.stop_circle
                      : Icons.bubble_chart,
                ),
                label: Text(
                  bubbleRunning
                      ? 'Stop Translate X Bubble'
                      : 'Start Floating Bubble',
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Offline mode: Internet translation के लिए जरूरी नहीं है। '
              'Language models device पर download होकर local translation करते हैं.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageDropdown(
    String title,
    LanguageItem selected,
    ValueChanged<LanguageItem?> onChanged,
  ) {
    return DropdownButtonFormField<LanguageItem>(
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: title,
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      items: languages.map((item) {
        return DropdownMenuItem<LanguageItem>(
          value: item,
          child: Text(item.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ============================================================
// FLOATING OVERLAY ENTRY POINT
// ============================================================

@pragma('vm:entry-point')
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TranslateXBubble(),
    ),
  );
}

class TranslateXBubble extends StatelessWidget {
  const TranslateXBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () async {
          // Bubble tapped.
          // Next stage:
          // Screen capture/OCR -> Translation -> Result.
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                spreadRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'TX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
