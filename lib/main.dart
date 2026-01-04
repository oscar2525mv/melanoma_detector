import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  final String? segmentationImage; // [1] Image Segmentation (URL ou Base64)
  final Map<String, dynamic>? resultJson; // [2] Résultats JSON
  final String? reportMd; // [3] Markdown
  final String? reportFile; // [4] Fichier
  final String? extraMd; // [5] Extra Markdown
  final List<List<double>>? contours; // Contours parsed from resultJson

  PredictResult({
    this.gradCamImage,
    this.segmentationImage,
    this.resultJson,
    this.reportMd,
    this.reportFile,
    this.extraMd,
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

    // Helper to parse contours
    List<List<double>>? parseContours(Map<String, dynamic>? json) {
      if (json == null) {
        debugPrint("parseContours: json is null");
        return null;
      }

      debugPrint(
        "parseContours: looking for 'contornos' in keys: ${json.keys.toList()}",
      );

      if (!json.containsKey('contornos')) {
        debugPrint("parseContours: 'contornos' key not found");
        return null;
      }

      try {
        var rawContours = json['contornos'];
        debugPrint(
          "parseContours: rawContours type = ${rawContours.runtimeType}",
        );
        debugPrint("parseContours: rawContours = $rawContours");

        if (rawContours == null ||
            (rawContours is List && rawContours.isEmpty)) {
          debugPrint("parseContours: contours is null or empty");
          return null;
        }

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
        debugPrint("parseContours: parsing ${list.length} points");

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
    debugPrint(
      "parseContours: final contours = ${contours?.length ?? 0} points",
    );

    return PredictResult(
      gradCamImage: asString(data.length > 0 ? data[0] : null),
      segmentationImage: asString(data.length > 1 ? data[1] : null),
      resultJson: jsonMap,
      reportMd: asString(data.length > 3 ? data[3] : null),
      reportFile: asString(data.length > 4 ? data[4] : null),
      extraMd: asString(data.length > 5 ? data[5] : null),
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

  /// Convertit un fichier image en Base64
  static Future<String> convertImageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    // Gradio attend souvent une data URL complète
    return 'data:image/jpeg;base64,$base64String';
  }

  /// Appelle l'API Gradio et attend le résultat
  static Future<PredictResult> predict({
    required File imageFile,
    required double threshold,
    required String mode,
    String? notes,
  }) async {
    // 1. Préparer l'image
    final String imageBase64 = await convertImageToBase64(imageFile);

    // 2. Préparer le payload (4 paramètres: image, threshold, mode, notes)
    final Map<String, dynamic> payload = {
      "data": [
        {
          "path": null,
          "url": imageBase64,
          "orig_name": "image.jpg",
          "size": imageFile.lengthSync(),
          "mime_type": "image/jpeg",
          "meta": {"_type": "gradio.FileData"},
        },
        threshold,
        mode,
        notes ?? "",
      ],
    };

    // 3. Envoyer la requête POST initiale (Call)
    final postResponse = await http
        .post(
          Uri.parse(_predictEndpoint),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (postResponse.statusCode != 200) {
      throw Exception(
        'Erreur POST: ${postResponse.statusCode} - ${postResponse.body}',
      );
    }

    // 4. Récupérer l'EVENT_ID
    // La réponse brute est: {"event_id": "..."}
    final postJson = jsonDecode(postResponse.body);
    final String eventId = postJson['event_id'];
    debugPrint("Analyse lancée. Event ID: $eventId");

    // 5. Polling pour récupérer le résultat (GET)
    // Gradio en mode SSE envoie des chunks: event: complete, data: [...]
    // Nous utiliserons une requête simple GET N périodique si possible, ou stream
    // Ici, implémentons un polling GET simple via http

    // Note: L'endpoint pour lire l'event stream est /call/predict_ui/{event_id}
    // C'est un Stream Server-Sent Events (SSE).
    // Dart http Client.send permet de consommer le stream.

    final request = http.Request(
      'GET',
      Uri.parse('$_predictEndpoint/$eventId'),
    );
    request.headers['Accept'] = 'text/event-stream';

    final streamedResponse = await http.Client()
        .send(request)
        .timeout(const Duration(seconds: 60));

    if (streamedResponse.statusCode != 200) {
      throw Exception('Erreur Stream: ${streamedResponse.statusCode}');
    }

    // Lire le flux ligne par ligne
    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? lastDataLine; // Guardar la última línea de datos para el error

    await for (String line in stream) {
      debugPrint("SSE: $line"); // Log para depuración

      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6); // Retirer "data: "
        lastDataLine = dataStr; // Guardar para mensajes de error

        if (dataStr.contains('generating') || dataStr.contains('heartbeat'))
          continue;

        try {
          // Si on reçoit l'erreur ici
          final decoded = jsonDecode(dataStr);
          if (decoded is List && decoded.isNotEmpty) {
            // C'est probablement le résultat si c'est une liste
            // Mais si c'est [null, null...] ou une erreur
            if (decoded[0] == "error") {
              throw Exception("Erreur API lue dans data: $decoded");
            }
            debugPrint("Analyse terminée. Reçu ${decoded.length} éléments.");
            return PredictResult.fromList(decoded);
          }
        } catch (_) {}
      }

      if (line.startsWith('event: error')) {
        // Extraer el mensaje de error del último data recibido
        String errorDetail = lastDataLine ?? "Sin detalles";
        throw Exception("Error API Gradio: $errorDetail");
      }
    }

    throw Exception("Le flux s'est terminé sans résultat 'complete'.");
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

  // Options Mode (doivent correspondre EXACTEMENT à l'API)
  final List<String> _modeOptions = [
    'Rápido (Solo Local)',
    'Preciso (Ensemble/Comité)',
  ];
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = _modeOptions[0]; // Rápido par défaut
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
                final isRapido = mode.contains('Rápido');
                return ButtonSegment(
                  value: mode,
                  label: Text(
                    isRapido ? '⚡ Rapide' : '🧠 Précis',
                    style: const TextStyle(fontSize: 12),
                  ),
                  icon: Icon(isRapido ? Icons.speed : Icons.psychology),
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
          _selectedMode.contains('Rápido')
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
      // prediccion_final
      final pred =
          (json['prediccion_final'] ?? json['prediccion'] ?? '')
              .toString()
              .toLowerCase();
      if (pred.isNotEmpty) {
        isMalignant =
            pred.contains('malignant') ||
            pred.contains('maligne') ||
            pred.contains('melanoma');
        diagnosis = isMalignant ? "Mélanome (Maligne)" : "Bénin";
      }

      // prob_malignidad (probabilidad de malignidad)
      final confValue =
          json['prob_malignidad'] ?? json['prob_promedio'] ?? json['confianza'];
      if (confValue != null) {
        confidence = double.tryParse(confValue.toString()) ?? 0.0;
      }
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

        // 2. Images (Restored)
        const Text(
          "Analyse Visuelle",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (res.gradCamImage != null)
              Expanded(
                child: _buildResultImage(
                  "Carte de Chaleur (Grad-CAM)",
                  res.gradCamImage!,
                ),
              ),
            if (res.segmentationImage != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildResultImage(
                  "Segmentation",
                  res.segmentationImage!,
                ),
              ),
            ],
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

              // Dimensions / Pixels (tamano de la API)
              _buildInfoRow(
                Icons.aspect_ratio,
                "Surface (Pixels)",
                "${res.resultJson?['tamano']?['area_px'] ?? 'N/A'}",
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.circle_outlined,
                "Diamètre Équivalent",
                "${res.resultJson?['tamano']?['diam_px']?.toStringAsFixed(1) ?? 'N/A'} px",
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
