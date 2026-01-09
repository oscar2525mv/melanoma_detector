import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'border_editor.dart';

void main() {
  runApp(const MelanomaDetectorApp());
}

// =============================================================================
// MODÈLE DE DONNÉES / DTOs
// =============================================================================

class PredictResult {
  final String? gradCamImage; // [0] Image Grad-CAM (URL ou Base64)
  final String? segmentationUnetImage; // [1] Nouvelle: Masque U-Net (vert)
  final String?
  segmentationOpencvImage; // [2] Déplacé: Masque OpenCV (bleu/rouge)
  final String? reportMd; // [3] Markdown
  final Map<String, dynamic>? resultJson; // [4] Déplacé: Résultats JSON
  final String? reportFile; // [5] Fichier
  final List<List<double>>? contours; // Contours parsed from resultJson

  // Accessor pour compatibilité: préfère U-Net, sinon OpenCV
  String? get segmentationImage =>
      segmentationUnetImage ?? segmentationOpencvImage;

  PredictResult({
    this.gradCamImage,
    this.segmentationUnetImage,
    this.segmentationOpencvImage,
    this.resultJson,
    this.reportMd,
    this.reportFile,
    this.contours,
  });

  factory PredictResult.fromList(List<dynamic> data) {
    // DEBUG: Ver exactamente qué viene en cada posición
    debugPrint("=== PredictResult.fromList DEBUG ===");
    debugPrint("data.length = ${data.length}");
    for (int i = 0; i < data.length && i < 6; i++) {
      final item = data[i];
      debugPrint("data[$i] type: ${item.runtimeType}");
      if (item is String && item.length > 100) {
        debugPrint("data[$i] value (truncated): ${item.substring(0, 100)}...");
      } else {
        debugPrint("data[$i] value: $item");
      }
    }
    debugPrint("=== END DEBUG ===");

    // Helper pour extraire string ou null
    // IMPORTANT: Ne convertit PAS les Maps en string!
    String? asString(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      // Priorité à 'url' qui est fait pour l'accès web
      if (v is Map && v.containsKey('url')) return v['url'];
      if (v is Map && v.containsKey('path')) return v['path'];
      // Si c'est un Map sans url/path, retourner null (ne pas convertir en string!)
      if (v is Map) return null;
      return v.toString();
    }

    // Helper pour json - extrae Map directamente
    Map<String, dynamic>? asJson(dynamic v) {
      if (v == null) return null;
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String) {
        // Intentar parsear como JSON si parece ser JSON
        final trimmed = v.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            return jsonDecode(v);
          } catch (e) {
            debugPrint("asJson: failed to parse JSON string: $e");
          }
        }
      }
      return null;
    }

    // Buscar el JSON en CUALQUIER posición (la API puede cambiar)
    Map<String, dynamic>? jsonMap;
    int jsonPosition = -1;
    for (int i = 0; i < data.length && jsonMap == null; i++) {
      jsonMap = asJson(data[i]);
      if (jsonMap != null && jsonMap.containsKey('prediccion_final')) {
        jsonPosition = i;
        debugPrint("Found valid JSON with prediccion_final in position $i");
        break;
      }
      jsonMap = null; // Reset if it doesn't have prediccion_final
    }

    // Si no encontramos JSON con prediccion_final, buscar cualquier Map válido
    if (jsonMap == null) {
      for (int i = 0; i < data.length && jsonMap == null; i++) {
        jsonMap = asJson(data[i]);
        if (jsonMap != null) {
          jsonPosition = i;
          debugPrint(
            "Found generic JSON in position $i with keys: ${jsonMap.keys.toList()}",
          );
        }
      }
    }

    // Helper to parse contours from new Ensemble structure
    List<List<double>>? parseContours(Map<String, dynamic>? json) {
      if (json == null) return null;

      var rawContours;

      // 1. Try New Structure (Ensemble)
      if (json.containsKey('segmentacion')) {
        final seg = json['segmentacion'];
        if (seg is Map) {
          // Priority: U-Net
          if (seg.containsKey('unet') &&
              seg['unet'] is Map &&
              seg['unet']['disponible'] == true &&
              seg['unet']['contornos'] != null) {
            debugPrint("parseContours: Using U-Net contours");
            rawContours = seg['unet']['contornos'];
          }
          // Fallback: OpenCV
          else if (seg.containsKey('opencv') &&
              seg['opencv'] is Map &&
              seg['opencv']['contornos'] != null) {
            debugPrint("parseContours: Using OpenCV contours (fallback)");
            rawContours = seg['opencv']['contornos'];
          }
        }
      }

      // 2. Legacy/Simple Structure
      if (rawContours == null && json.containsKey('contornos')) {
        rawContours = json['contornos'];
      }

      if (rawContours == null || (rawContours is List && rawContours.isEmpty)) {
        return null;
      }

      try {
        // Handle deeply nested structure: [[[x,y], [x,y]...]] -> [[x,y], [x,y]...]
        if (rawContours is List && rawContours.isNotEmpty) {
          var unwrapped = rawContours;
          // Unwrap until we get to actual points
          while (unwrapped is List &&
              unwrapped.isNotEmpty &&
              unwrapped[0] is List &&
              unwrapped[0].isNotEmpty &&
              unwrapped[0][0] is List) {
            unwrapped = unwrapped[0];
          }
          rawContours = unwrapped;
        }

        final list = rawContours as List;
        return list.map((point) {
          final coords = point as List;
          return [
            double.parse(coords[0].toString()),
            double.parse(coords[1].toString()),
          ];
        }).toList();
      } catch (e) {
        debugPrint("Error parsing contours: $e");
        return null;
      }
    }

    final contours = parseContours(jsonMap);

    return PredictResult(
      gradCamImage: asString(data.length > 0 ? data[0] : null),
      segmentationUnetImage: asString(
        data.length > 1 ? data[1] : null,
      ), // Index 1: U-Net Mask (Green)
      segmentationOpencvImage: asString(
        data.length > 2 ? data[2] : null,
      ), // Index 2: OpenCV Mask (Blue/Red)
      resultJson: jsonMap, // Index 4: Full JSON
      reportMd: asString(data.length > 3 ? data[3] : null), // Index 3: Markdown
      reportFile: asString(
        data.length > 5 ? data[5] : null,
      ), // Index 5: Report File
      contours: contours,
    );
  }
}

// =============================================================================
// SERVICE API
// =============================================================================

class MelanomaService {
  static const String _baseUrl =
      'https://oscar2525mv-melanoma.hf.space/gradio_api';
  static const String _predictEndpoint = '$_baseUrl/call/predict_ui';

  /// Upload image to Gradio and get file path
  static Future<String> uploadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final fileName = imageFile.path.split('/').last.split('\\').last;

    // Determine MIME type
    String mimeType = 'image/jpeg';
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (lowerName.endsWith('.webp')) {
      mimeType = 'image/webp';
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/upload'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60), // Increased for cold start
    );
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("Upload Response Status: ${response.statusCode}");
    debugPrint("Upload Response Body: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur upload: ${response.statusCode} - ${response.body}',
      );
    }

    final List<dynamic> uploadResult = jsonDecode(response.body);
    if (uploadResult.isEmpty) {
      throw Exception('Upload returned empty result');
    }

    // Returns the file path on the server
    return uploadResult[0] as String;
  }

  /// Appelle l'API Gradio et attend le résultat
  static Future<PredictResult> predict({
    required File imageFile,
    required double threshold,
    required String mode,
    String? notes,
  }) async {
    // 1. Upload image first (méthode officielle Gradio)
    final String uploadedPath = await uploadImage(imageFile);
    debugPrint("Image uploaded to path: $uploadedPath");

    // 2. Préparer le payload avec le path uploadé
    // IMPORTANT: Gradio 4.x format for file input
    debugPrint("=== DEBUG PAYLOAD ===");
    debugPrint("Mode envoyé: '$mode'");
    debugPrint("Threshold: $threshold");
    debugPrint("Notes: '${notes ?? ""}'");

    final Map<String, dynamic> payload = {
      "data": [
        // Image input - format Gradio 4.x
        {
          "path": uploadedPath,
          "url": null,
          "size": null,
          "orig_name": imageFile.path.split('/').last.split('\\').last,
          "mime_type": null,
        },
        threshold, // Slider value
        mode, // Radio value (exact string match required)
        notes ?? "", // Textbox value
      ],
    };

    debugPrint("Payload JSON: ${jsonEncode(payload)}");

    // 3. Envoyer la requête POST initiale (Call)
    final postResponse = await http
        .post(
          Uri.parse(_predictEndpoint),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60)); // Increased for cold start

    debugPrint("POST Response Status: ${postResponse.statusCode}");
    debugPrint("POST Response Body: ${postResponse.body}");

    if (postResponse.statusCode != 200) {
      throw Exception(
        'Erreur POST (${postResponse.statusCode}): ${postResponse.body}',
      );
    }

    // 4. Récupérer l'EVENT_ID
    final postJson = jsonDecode(postResponse.body);
    final String eventId = postJson['event_id'];
    debugPrint("Analyse lancée. Event ID: $eventId");

    // 5. Lire le stream SSE pour les résultats
    final request = http.Request(
      'GET',
      Uri.parse('$_predictEndpoint/$eventId'),
    );
    request.headers['Accept'] = 'text/event-stream';

    final streamedResponse = await http.Client()
        .send(request)
        .timeout(
          const Duration(seconds: 300), // 5 min pour cold start + ensemble
        );

    if (streamedResponse.statusCode != 200) {
      throw Exception('Erreur Stream (${streamedResponse.statusCode})');
    }

    // Lire le flux ligne par ligne
    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    List<String> allLines = [];
    String? currentEvent;

    await for (String line in stream) {
      debugPrint("SSE: $line");
      allLines.add(line);

      // Track event type
      if (line.startsWith('event: ')) {
        currentEvent = line.substring(7).trim();
        debugPrint("Event type: $currentEvent");

        // Handle error event
        if (currentEvent == 'error') {
          // Wait for the data line that should follow
          continue;
        }
        continue;
      }

      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6);

        // Skip heartbeat/progress messages
        if (dataStr.contains('"heartbeat"') ||
            dataStr.contains('"generating"') ||
            dataStr.contains('"progress"')) {
          continue;
        }

        // Handle error data
        if (currentEvent == 'error') {
          throw Exception('Erreur API Gradio: $dataStr');
        }

        try {
          final decoded = jsonDecode(dataStr);

          // Check for error in data
          if (decoded is Map && decoded.containsKey('error')) {
            throw Exception('Erreur API: ${decoded['error']}');
          }

          if (decoded is List && decoded.isNotEmpty) {
            // Check if first element is error indicator
            if (decoded[0] == "error" || decoded[0] == "__error__") {
              throw Exception(
                "Erreur API: ${decoded.length > 1 ? decoded[1] : decoded}",
              );
            }
            debugPrint("Analyse terminée. Reçu ${decoded.length} éléments.");
            return PredictResult.fromList(decoded);
          }
        } catch (e) {
          if (e.toString().contains('Erreur API') ||
              e.toString().contains('Error')) {
            rethrow;
          }
          // JSON parse error on intermediate message, continue
          debugPrint("JSON parse non-fatal: $e");
        }
      }
    }

    // Stream ended without result
    final lastLines =
        allLines.length > 10
            ? allLines.sublist(allLines.length - 10)
            : allLines;
    throw Exception(
      "Le flux SSE s'est terminé sans résultat valide.\n"
      "Dernières lignes:\n${lastLines.join('\n')}",
    );
  }
}

// =============================================================================
// APPLICATION PRINCIPALE
// =============================================================================

class MelanomaDetectorApp extends StatelessWidget {
  const MelanomaDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Détecteur de Mélanome (Natif)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1B1F),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
      ),
      home: const MelanomaNativePage(),
    );
  }
}

// =============================================================================
// PAGE PRINCIPALE
// =============================================================================

class MelanomaNativePage extends StatefulWidget {
  const MelanomaNativePage({super.key});

  @override
  State<MelanomaNativePage> createState() => _MelanomaNativePageState();
}

class _MelanomaNativePageState extends State<MelanomaNativePage> {
  // États du formulaire
  File? _selectedImage;
  bool _isLoading = false;
  PredictResult? _result;
  String? _errorMessage;

  // Paramètres
  double _threshold = 0.5;
  final TextEditingController _notesController = TextEditingController();

  // Options Mode (doivent correspondre EXACTEMENT à l'API Ensemble)
  final List<String> _modeOptions = [
    'Rapide (Local seulement)',
    'Précis (Ensemble/Comité)',
  ];
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = _modeOptions[0]; // Rapide par défaut
    _requestPermissions();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    if (Platform.isAndroid) {
      if (await Permission.photos.status.isDenied) {
        await Permission.photos.request();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _result = null; // Reset resultats
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showError("Erreur sélection image: $e");
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await MelanomaService.predict(
        imageFile: _selectedImage!,
        threshold: _threshold,
        mode: _selectedMode,
        notes: _notesController.text,
      );

      setState(() {
        _result = result;
      });
    } catch (e) {
      _showError("Erreur analyse: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _result = null;
      _errorMessage = null;
      _notesController.clear();
      _selectedMode = _modeOptions[0];
      _threshold = 0.5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détecteur Mélanome (Natif)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Réinitialiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDisclaimer(),
            const SizedBox(height: 20),
            _buildImageSection(),
            const SizedBox(height: 20),

            // Si on a un résultat, on l'affiche, sinon on affiche le formulaire
            if (_result != null)
              _buildResultsSection()
            else
              _buildFormSection(),

            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              const Text(
                "Analyse en cours via Hugging Face...",
                textAlign: TextAlign.center,
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Text(
                  "❌ $_errorMessage",
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Ce logiciel est uniquement destiné à la recherche/éducation. Il ne remplace pas un diagnostic médical.",
              style: TextStyle(fontSize: 12, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceDialog,
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          image:
              _selectedImage != null
                  ? DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  )
                  : null,
        ),
        child:
            _selectedImage == null
                ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      "Appuyez pour ajouter une image",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
                : null,
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Paramètres",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Seuil
        Text("Seuil de détection: ${_threshold.toStringAsFixed(2)}"),
        Slider(
          value: _threshold,
          min: 0.3,
          max: 0.7,
          divisions: 40,
          label: _threshold.toStringAsFixed(2),
          onChanged: _isLoading ? null : (v) => setState(() => _threshold = v),
        ),

        // Mode Selector
        const SizedBox(height: 16),
        const Text(
          "Mode d'analyse:",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments:
              _modeOptions.map((mode) {
                final isRapide = mode.contains('Rapide');
                return ButtonSegment(
                  value: mode,
                  label: Text(
                    isRapide ? '⚡ Rapide' : '🧠 Précis',
                    style: const TextStyle(fontSize: 12),
                  ),
                  icon: Icon(isRapide ? Icons.speed : Icons.psychology),
                );
              }).toList(),
          selected: {_selectedMode},
          onSelectionChanged:
              _isLoading
                  ? null
                  : (Set<String> selection) {
                    setState(() => _selectedMode = selection.first);
                  },
        ),
        const SizedBox(height: 4),
        Text(
          _selectedMode.contains('Rapide')
              ? 'Analyse rapide avec modèle local uniquement'
              : 'Analyse précise avec ensemble de modèles IA',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),

        // Notes
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          enabled: !_isLoading,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes (optionnel)',
            prefixIcon: Icon(Icons.note),
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: (_selectedImage == null || _isLoading) ? null : _analyze,
            icon: const Icon(Icons.analytics),
            label: const Text("LANCER L'ANALYSE"),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final res = _result!;
    final json = res.resultJson;

    // DEBUG: Imprimir estructura JSON completa
    debugPrint("=== DEBUG: resultJson ===");
    debugPrint("$json");
    debugPrint("=== Claves disponibles: ${json?.keys.toList()} ===");

    String diagnosis = "Résultat inconnu";
    double confidence = 0.0;
    bool isMalignant = false;

    // Parsing du JSON con los nombres correctos de la API
    if (json != null) {
      // 1. PRIMERO: Obtener prob_malignidad
      final confValue =
          json['prob_malignidad'] ?? json['prob_promedio'] ?? json['confianza'];
      if (confValue != null) {
        double rawConf = double.tryParse(confValue.toString()) ?? 0.0;
        // Si el valor es > 1, está en formato porcentaje (ej: 94.29), convertir a decimal
        confidence = rawConf > 1.0 ? rawConf / 100.0 : rawConf;
      }

      debugPrint("=== DIAGNOSTIC MALIGNANCY ===");
      debugPrint("prob_malignidad raw: ${json['prob_malignidad']}");
      debugPrint("prob_malignidad normalized (0-1): $confidence");

      // 2. Intentar usar prediccion_final del API
      final rawPred = json['prediccion_final'] ?? json['prediccion'] ?? '';
      final pred = rawPred.toString().toLowerCase().trim();
      debugPrint("prediccion_final: '$rawPred'");

      if (pred.isNotEmpty && pred != 'null') {
        // API devuelve "Malin" o "Bénin"
        isMalignant =
            pred.contains('malin') ||
            pred.contains('malignant') ||
            pred.contains('melanoma');
        diagnosis = isMalignant ? "Mélanome (Maligne)" : "Bénin";
        debugPrint("From prediccion_final -> isMalignant: $isMalignant");
      } else {
        // FALLBACK: usar prob_malignidad >= 0.5
        isMalignant = confidence >= 0.5;
        diagnosis = isMalignant ? "Mélanome (Maligne)" : "Bénin";
        debugPrint("FALLBACK from prob >= 0.5 -> isMalignant: $isMalignant");
      }
      debugPrint("=== END: diagnosis=$diagnosis, isMalignant=$isMalignant ===");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 10),

        // 1. Diagnosis Card (Huge & Colored)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isMalignant
                    ? Colors.red.shade900.withOpacity(0.8)
                    : Colors.green.shade900.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    isMalignant
                        ? Colors.red.withOpacity(0.4)
                        : Colors.green.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                isMalignant
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                diagnosis.toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Confiance IA: ${(confidence * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 2. Images (Grad-CAM + Dual Segmentation)
        const Text(
          "Analyse Visuelle",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Row 1: Grad-CAM
        if (res.gradCamImage != null)
          _buildResultImage("Carte de Chaleur (Grad-CAM)", res.gradCamImage!),
        const SizedBox(height: 12),
        // Row 2: Dual Segmentation (U-Net + OpenCV si disponibles)
        Row(
          children: [
            if (res.segmentationUnetImage != null)
              Expanded(
                child: _buildResultImage(
                  "Segmentation IA (U-Net)",
                  res.segmentationUnetImage!,
                ),
              ),
            if (res.segmentationUnetImage != null &&
                res.segmentationOpencvImage != null)
              const SizedBox(width: 12),
            if (res.segmentationOpencvImage != null)
              Expanded(
                child: _buildResultImage(
                  "Segmentation Classique",
                  res.segmentationOpencvImage!,
                ),
              ),
          ],
        ),

        // 2.1 Edit Contours Button
        if (res.contours != null &&
            res.contours!.isNotEmpty &&
            _selectedImage != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_location_alt),
              label: const Text("MODIFIER LA SEGMENTATION"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => BorderEditorPage(
                          imageFile: _selectedImage!,
                          initialContours: res.contours!,
                          mmPerPixel: 0.0, // mmPerPixel n'est plus dans l'API
                        ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 3. Technical Details (Visual + Report)
        Text(
          "Détails Techniques",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade100,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Détail des modèles (visible avec API Ensemble)
              if (res.resultJson?['modelos_binarios'] != null) ...[
                const Text(
                  "Modèles Binaires IA:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                ...((res.resultJson!['modelos_binarios']
                        as Map<String, dynamic>)
                    .entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "${((e.value as num) * 100).toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    (e.value as num) > 0.5
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                const Divider(height: 24),
              ],

              // Ranking de categorías
              if (res.resultJson?['ranking_categorias'] != null) ...[
                const Text(
                  "Ranking de Catégories:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                ...(() {
                  final ranking =
                      res.resultJson!['ranking_categorias']
                          as Map<String, dynamic>;

                  // Helper para normalizar score a porcentaje
                  double normalizeScore(num score) =>
                      score > 1 ? score.toDouble() : score * 100;

                  // Ordenar por score_promedio normalizado (descendiente)
                  final sortedEntries =
                      ranking.entries.toList()..sort((a, b) {
                        final scoreA = normalizeScore(
                          (a.value['score_promedio'] ?? 0.0) as num,
                        );
                        final scoreB = normalizeScore(
                          (b.value['score_promedio'] ?? 0.0) as num,
                        );
                        return scoreB.compareTo(scoreA);
                      });

                  return sortedEntries.map((entry) {
                    final data = entry.value as Map<String, dynamic>;
                    final score = (data['score_promedio'] ?? 0.0) as num;
                    final isMaligna = data['es_maligna'] == true;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            isMaligna
                                ? Icons.warning_amber
                                : Icons.check_circle_outline,
                            size: 14,
                            color:
                                isMaligna
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            // Si score > 1, ya es porcentaje; si no, multiplicar por 100
                            "${(score > 1 ? score : score * 100).toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isMaligna
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                })(),
                const Divider(height: 24),
              ],

              const Divider(height: 32),

              // Dimensions / Pixels - Lecture depuis segmentacion.unet ou opencv
              _buildInfoRow(
                Icons.aspect_ratio,
                "Surface (Pixels)",
                "${_getSegmentationValue(res.resultJson, 'area_px') ?? 'N/A'}",
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.circle_outlined,
                "Diamètre Équivalent",
                "${_getSegmentationValue(res.resultJson, 'diam_px')?.toStringAsFixed(1) ?? 'N/A'} px",
              ),

              // Markdown Report (Merged here)
              if (res.reportMd != null && res.reportMd!.isNotEmpty) ...[
                const Divider(height: 32),
                const Text(
                  "Rapport:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  res.reportMd!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 40),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _result = null),
            label: const Text("NOUVELLE ANALYSE"),
          ),
        ),
      ],
    );
  }

  Widget _buildProbabilityRow(String label, dynamic value) {
    double prob = 0.0;
    if (value is num) prob = value.toDouble();

    // Color logic
    bool isMalignant = label.toLowerCase().contains("mélanome");
    Color color = isMalignant ? Colors.redAccent : Colors.greenAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              "${(prob * 100).toStringAsFixed(1)}%",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: prob,
          backgroundColor: Colors.grey.withOpacity(0.2),
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Helper pour lire les valeurs de segmentation depuis la nouvelle structure
  /// Priorité: segmentacion.unet.tamano.[key] -> segmentacion.opencv.tamano.[key] -> tamano.[key] (legacy)
  dynamic _getSegmentationValue(Map<String, dynamic>? json, String key) {
    if (json == null) return null;

    // 1. Essayer nouvelle structure Ensemble
    if (json.containsKey('segmentacion')) {
      final seg = json['segmentacion'];
      if (seg is Map) {
        // Priorité U-Net si disponible
        if (seg['unet']?['disponible'] == true &&
            seg['unet']?['tamano']?[key] != null) {
          return seg['unet']['tamano'][key];
        }
        // Fallback OpenCV
        if (seg['opencv']?['tamano']?[key] != null) {
          return seg['opencv']['tamano'][key];
        }
      }
    }

    // 2. Legacy structure (tamano à la racine)
    return json['tamano']?[key];
  }

  Widget _buildResultImage(String title, String src) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageFromSrc(src),
          ),
        ),
      ],
    );
  }

  Widget _buildImageFromSrc(String src) {
    if (src.startsWith('data:image')) {
      final base64Str = src.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        height: 160,
      );
    }

    // Construction URL
    String fullUrl = src;
    if (!src.startsWith('http')) {
      final baseUrl = "https://oscar2525mv-melanoma.hf.space";
      // Si le path commence déjà par /file= (via la propriété 'url' de l'API), on le concatène juste
      if (src.startsWith('/file=')) {
        fullUrl = "$baseUrl$src";
      } else {
        // Sinon (cas propriété 'path'), on ajoute le préfixe
        fullUrl = "$baseUrl/file=$src";
      }
    }

    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse(fullUrl)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 160,
            width: double.infinity,
            color: Colors.grey.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorBox(fullUrl, "NetErr: ${snapshot.error}");
        }

        final response = snapshot.data!;

        if (response.statusCode == 200) {
          // Check header content-type if possible, but let's try decode
          return Image.memory(
            response.bodyBytes,
            fit: BoxFit.cover,
            height: 160,
            errorBuilder: (_, err, __) {
              String bodySample = "";
              try {
                bodySample =
                    response.body.length < 200
                        ? response.body
                        : response.body.substring(0, 200);
              } catch (e) {
                bodySample = "Bin data";
              }
              return _buildErrorBox(fullUrl, "DecodeErr. Body: $bodySample");
            },
          );
        } else {
          return _buildErrorBox(fullUrl, "HTTP ${response.statusCode}");
        }
      },
    );
  }

  Widget _buildErrorBox(String url, String error) {
    return Container(
      height: 160,
      width: double.infinity,
      color: Colors.grey.withOpacity(0.2),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, color: Colors.grey),
              Text(
                error,
                style: const TextStyle(fontSize: 10, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                url.split('/').last,
                style: const TextStyle(fontSize: 8, color: Colors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
