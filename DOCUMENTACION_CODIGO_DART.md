# 📚 Documentación Exhaustiva del Código Dart - Melanoma Detector

**Versión:** 1.0  
**Fecha:** 05 de Enero 2026  
**Autor:** Generado automáticamente  

---

## 📋 Tabla de Contenidos

1. [Visión General del Proyecto](#visión-general-del-proyecto)
2. [Archivo: main.dart](#archivo-maindart)
   - [Importaciones](#1-importaciones-líneas-1-12)
   - [Función Principal](#2-función-principal-main-líneas-14-16)
   - [Modelo de Datos PredictResult](#3-modelo-de-datos-predictresult-líneas-22-186)
   - [Servicio API MelanomaService](#4-servicio-api-melanomaservice-líneas-193-318)
   - [Aplicación Principal](#5-aplicación-principal-melanomadetectorapp-líneas-324-349)
   - [Página Principal](#6-página-principal-melanomanativepage-líneas-355-1231)
3. [Archivo: border_editor.dart](#archivo-border_editordart)
   - [Clase BorderEditorPage](#clase-bordereditorpage-líneas-7-21)
   - [Estado del Editor](#estado-del-editor-líneas-23-271)
   - [CustomPainter _EditorPainter](#custompainter-_editorpainter-líneas-274-332)
4. [Glosario de Términos](#glosario-de-términos)
5. [Diagramas de Flujo](#diagramas-de-flujo)

---

## Visión General del Proyecto

Este proyecto es una **aplicación móvil Flutter** para la detección de melanomas mediante inteligencia artificial. La aplicación permite:

- 📷 Capturar o seleccionar imágenes de lesiones cutáneas
- 🧠 Enviar las imágenes a una API de Hugging Face para análisis
- 📊 Mostrar resultados con probabilidades y visualizaciones
- ✏️ Editar interactivamente los contornos de segmentación detectados

---

## Archivo: main.dart

Este es el archivo principal de la aplicación con **1232 líneas** de código.

---

### 1. Importaciones (Líneas 1-12)

```dart
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
```

#### Explicación línea por línea:

| Línea | Código | Descripción |
|-------|--------|-------------|
| 1 | `import 'dart:async';` | Importa la librería para operaciones asíncronas (Future, Stream, Completer, etc.) |
| 2 | `import 'dart:convert';` | Proporciona codificadores/decodificadores JSON y Base64 (`jsonEncode`, `jsonDecode`, `base64Encode`) |
| 3 | `import 'dart:io';` | Acceso a operaciones de entrada/salida del sistema (archivos, sockets). Permite usar la clase `File` |
| 5 | `import 'package:flutter/foundation.dart';` | Utilidades fundamentales de Flutter como `debugPrint` para logging |
| 6 | `import 'package:flutter/material.dart';` | Framework de widgets Material Design de Flutter |
| 7 | `import 'package:http/http.dart' as http;` | Cliente HTTP para hacer peticiones REST. El alias `http` evita conflictos de nombres |
| 8 | `import 'package:image_picker/image_picker.dart';` | Plugin para seleccionar imágenes de la galería o cámara |
| 9 | `import 'package:permission_handler/permission_handler.dart';` | Gestión de permisos del dispositivo (cámara, almacenamiento) |
| 10 | `import 'package:shared_preferences/shared_preferences.dart';` | Almacenamiento persistente de datos simples (clave-valor) |
| 12 | `import 'border_editor.dart';` | Importa el archivo local con el editor de bordes/contornos |

---

### 2. Función Principal main() (Líneas 14-16)

```dart
void main() {
  runApp(const MelanomaDetectorApp());
}
```

#### Explicación:

| Línea | Código | Descripción |
|-------|--------|-------------|
| 14 | `void main() {` | Punto de entrada de toda aplicación Dart. `void` indica que no retorna valor |
| 15 | `runApp(const MelanomaDetectorApp());` | `runApp()` infla el widget raíz y lo anexa a la pantalla. `const` optimiza memoria al crear una instancia constante en tiempo de compilación |
| 16 | `}` | Cierre de la función |

---

### 3. Modelo de Datos PredictResult (Líneas 22-186)

Esta clase representa la **respuesta estructurada** de la API de predicción.

#### 3.1 Declaración de la Clase (Líneas 22-39)

```dart
class PredictResult {
  final String? gradCamImage;        // [0] Image Grad-CAM (URL o Base64)
  final String? segmentationImage;   // [1] Image Segmentation (URL o Base64)
  final Map<String, dynamic>? resultJson; // [2] Résultats JSON
  final String? reportMd;            // [3] Markdown
  final String? reportFile;          // [4] Fichier
  final String? extraMd;             // [5] Extra Markdown
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
```

| Línea | Campo | Tipo | Descripción |
|-------|-------|------|-------------|
| 23 | `gradCamImage` | `String?` | URL o Base64 de la imagen Grad-CAM (mapa de calor de atención de la IA) |
| 24 | `segmentationImage` | `String?` | URL o Base64 de la imagen con la segmentación de la lesión |
| 25 | `resultJson` | `Map<String, dynamic>?` | Diccionario con todos los resultados JSON (predicción, probabilidad, etc.) |
| 26 | `reportMd` | `String?` | Texto en formato Markdown con el informe del análisis |
| 27 | `reportFile` | `String?` | Ruta al archivo del informe generado |
| 28 | `extraMd` | `String?` | Información adicional en Markdown |
| 29 | `contours` | `List<List<double>>?` | Lista de puntos [x, y] que definen el contorno de la lesión |

> **Nota:** El `?` después del tipo indica que el campo es **nullable** (puede ser `null`).

#### 3.2 Factory Constructor fromList (Líneas 41-186)

Este constructor transforma la respuesta de la API (lista) en un objeto estructurado:

```dart
factory PredictResult.fromList(List<dynamic> data) {
```

| Línea | Código | Descripción |
|-------|--------|-------------|
| 41 | `factory PredictResult.fromList(List<dynamic> data)` | Constructor factory que recibe la lista de respuesta de la API |
| 43-54 | Debug logging | Imprime información de depuración sobre cada elemento recibido |
| 58-67 | Función `asString()` | Helper que extrae strings de forma segura, manejando URLs embebidas en Maps |
| 70-85 | Función `asJson()` | Helper que extrae y parsea JSON, manejando tanto Maps como Strings |
| 87-111 | Búsqueda de JSON | Itera sobre los datos buscando un Map con la clave `prediccion_final` |
| 114-170 | Función `parseContours()` | Parsea recursivamente los contornos anidados hasta encontrar los puntos [x,y] |
| 177-186 | Construcción del objeto | Crea y retorna el `PredictResult` con todos los campos parseados |

**Detalle de la función `parseContours`:**

```dart
List<List<double>>? parseContours(Map<String, dynamic>? json) {
  // Verificación de nulidad
  if (json == null) return null;
  
  // Verificar si existe la clave 'contornos'
  if (!json.containsKey('contornos')) return null;
  
  try {
    var rawContours = json['contornos'];
    
    // Desempaquetar estructuras profundamente anidadas: [[[x,y]...]] -> [[x,y]...]
    if (rawContours is List && rawContours.isNotEmpty) {
      var unwrapped = rawContours;
      while (unwrapped is List &&
             unwrapped.isNotEmpty &&
             unwrapped[0] is List &&
             unwrapped[0][0] is List) {
        unwrapped = unwrapped[0];  // Quitar un nivel de anidación
      }
      rawContours = unwrapped;
    }
    
    // Convertir cada punto a [double, double]
    return rawContours.map((point) {
      return [
        double.parse(point[0].toString()),
        double.parse(point[1].toString()),
      ];
    }).toList();
  } catch (e) {
    debugPrint("Error parsing contours: $e");
    return null;
  }
}
```

---

### 4. Servicio API MelanomaService (Líneas 193-318)

Clase estática que encapsula toda la comunicación con la API de Hugging Face.

#### 4.1 Constantes (Líneas 194-196)

```dart
class MelanomaService {
  static const String _baseUrl =
      'https://oscar2525mv-melanoma.hf.space/gradio_api';
  static const String _predictEndpoint = '$_baseUrl/call/predict_ui';
```

| Línea | Constante | Valor | Descripción |
|-------|-----------|-------|-------------|
| 194-195 | `_baseUrl` | `https://oscar2525mv-melanoma.hf.space/gradio_api` | URL base de la API Gradio en Hugging Face |
| 196 | `_predictEndpoint` | `$_baseUrl/call/predict_ui` | Endpoint completo para las predicciones |

#### 4.2 Conversión de Imagen a Base64 (Líneas 198-204)

```dart
static Future<String> convertImageToBase64(File imageFile) async {
  final bytes = await imageFile.readAsBytes();       // Lee bytes del archivo
  final base64String = base64Encode(bytes);          // Codifica en Base64
  return 'data:image/jpeg;base64,$base64String';     // Retorna Data URL
}
```

| Paso | Descripción |
|------|-------------|
| 1 | Lee todos los bytes del archivo de imagen de forma asíncrona |
| 2 | Codifica los bytes en una cadena Base64 |
| 3 | Construye una Data URL con el prefijo MIME type para JPEG |

#### 4.3 Método predict() (Líneas 206-317)

Este es el método principal que realiza la predicción:

```dart
static Future<PredictResult> predict({
  required File imageFile,
  required double threshold,
  required String mode,
  String? notes,
}) async {
```

**Parámetros:**

| Parámetro | Tipo | Obligatorio | Descripción |
|-----------|------|-------------|-------------|
| `imageFile` | `File` | ✅ | Archivo de imagen a analizar |
| `threshold` | `double` | ✅ | Umbral de detección (0.3-0.7) |
| `mode` | `String` | ✅ | Modo de análisis ("Rápido" o "Preciso") |
| `notes` | `String?` | ❌ | Notas adicionales opcionales |

**Flujo de ejecución:**

```
┌─────────────────────────────────────────────────────────────┐
│  1. Convertir imagen a Base64                               │
├─────────────────────────────────────────────────────────────┤
│  2. Construir payload JSON con los 4 parámetros             │
├─────────────────────────────────────────────────────────────┤
│  3. POST al endpoint → Obtener event_id                     │
├─────────────────────────────────────────────────────────────┤
│  4. GET con SSE (Server-Sent Events) al event_id           │
├─────────────────────────────────────────────────────────────┤
│  5. Parsear stream SSE y extraer resultado                  │
├─────────────────────────────────────────────────────────────┤
│  6. Retornar PredictResult.fromList(data)                   │
└─────────────────────────────────────────────────────────────┘
```

**Detalle del Payload (Líneas 217-231):**

```dart
final Map<String, dynamic> payload = {
  "data": [
    {
      "path": null,
      "url": imageBase64,           // Imagen en Base64
      "orig_name": "image.jpg",     // Nombre original
      "size": imageFile.lengthSync(), // Tamaño en bytes
      "mime_type": "image/jpeg",    // Tipo MIME
      "meta": {"_type": "gradio.FileData"},  // Metadata Gradio
    },
    threshold,    // Umbral de detección
    mode,         // Modo de análisis
    notes ?? "",  // Notas (vacío si es null)
  ],
};
```

**Manejo de SSE (Server-Sent Events) (Líneas 277-314):**

```dart
final stream = streamedResponse.stream
    .transform(utf8.decoder)           // Decodificar bytes a UTF-8
    .transform(const LineSplitter());  // Dividir por líneas

await for (String line in stream) {
  if (line.startsWith('data: ')) {
    final dataStr = line.substring(6);  // Remover prefijo "data: "
    
    // Ignorar eventos de progreso
    if (dataStr.contains('generating') || dataStr.contains('heartbeat'))
      continue;
    
    try {
      final decoded = jsonDecode(dataStr);
      if (decoded is List && decoded.isNotEmpty) {
        return PredictResult.fromList(decoded);  // ¡Resultado exitoso!
      }
    } catch (_) {}
  }
  
  if (line.startsWith('event: error')) {
    throw Exception("Error API Gradio: $lastDataLine");
  }
}
```

---

### 5. Aplicación Principal MelanomaDetectorApp (Líneas 324-349)

Widget raíz que configura el tema y estructura de la aplicación.

```dart
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
          seedColor: const Color(0xFF6750A4),  // Color púrpura principal
          brightness: Brightness.dark,          // Tema oscuro
          surface: const Color(0xFF1C1B1F),     // Color de superficie
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
```

| Propiedad | Valor | Descripción |
|-----------|-------|-------------|
| `useMaterial3` | `true` | Usa Material Design 3 (último estándar de diseño) |
| `brightness` | `Brightness.dark` | Tema oscuro para la aplicación |
| `seedColor` | `0xFF6750A4` | Color base púrpura para generar la paleta |
| `surface` | `0xFF1C1B1F` | Color de fondo de las superficies |

---

### 6. Página Principal MelanomaNativePage (Líneas 355-1231)

#### 6.1 Declaración del StatefulWidget (Líneas 355-360)

```dart
class MelanomaNativePage extends StatefulWidget {
  const MelanomaNativePage({super.key});

  @override
  State<MelanomaNativePage> createState() => _MelanomaNativePageState();
}
```

> **StatefulWidget** se usa porque la página necesita mantener estado mutable (imagen seleccionada, resultados, etc.)

#### 6.2 Variables de Estado (Líneas 362-378)

```dart
class _MelanomaNativePageState extends State<MelanomaNativePage> {
  // Estados del formulario
  File? _selectedImage;           // Imagen seleccionada por el usuario
  bool _isLoading = false;        // Indicador de carga
  PredictResult? _result;         // Resultado de la predicción
  String? _errorMessage;          // Mensaje de error si ocurrió

  // Parámetros de análisis
  double _threshold = 0.5;        // Umbral de detección (por defecto 0.5)
  final TextEditingController _notesController = TextEditingController();

  // Opciones de modo de análisis
  final List<String> _modeOptions = [
    'Rápido (Solo Local)',
    'Preciso (Ensemble/Comité)',
  ];
  late String _selectedMode;
```

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `_selectedImage` | `File?` | `null` | Imagen del dispositivo a analizar |
| `_isLoading` | `bool` | `false` | Estado de carga durante análisis |
| `_result` | `PredictResult?` | `null` | Contiene los resultados después del análisis |
| `_errorMessage` | `String?` | `null` | Mensaje de error para mostrar al usuario |
| `_threshold` | `double` | `0.5` | Umbral de sensibilidad de detección |
| `_notesController` | `TextEditingController` | - | Controlador del campo de notas |
| `_modeOptions` | `List<String>` | 2 opciones | Modos disponibles de análisis |
| `_selectedMode` | `String` | Primer modo | Modo actualmente seleccionado |

#### 6.3 Ciclo de Vida (Líneas 380-400)

```dart
@override
void initState() {
  super.initState();
  _selectedMode = _modeOptions[0];  // Modo rápido por defecto
  _requestPermissions();             // Solicitar permisos al iniciar
}

@override
void dispose() {
  _notesController.dispose();        // Liberar recursos del controlador
  super.dispose();
}

Future<void> _requestPermissions() async {
  await Permission.camera.request();  // Solicitar permiso de cámara
  if (Platform.isAndroid) {
    if (await Permission.photos.status.isDenied) {
      await Permission.photos.request();  // Solicitar acceso a galería
    }
  }
}
```

| Método | Descripción |
|--------|-------------|
| `initState()` | Llamado una vez al crear el widget. Inicializa valores y permisos |
| `dispose()` | Llamado al destruir el widget. Libera recursos para evitar memory leaks |
| `_requestPermissions()` | Solicita permisos de cámara y galería al dispositivo |

#### 6.4 Selección de Imagen (Líneas 402-449)

```dart
Future<void> _pickImage(ImageSource source) async {
  try {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: source,      // Cámara o Galería
      maxWidth: 1024,      // Redimensionar a máximo 1024px de ancho
      maxHeight: 1024,     // Redimensionar a máximo 1024px de alto
    );
    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _result = null;       // Limpiar resultados anteriores
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
    builder: (_) => SafeArea(
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
```

#### 6.5 Método de Análisis (Líneas 451-476)

```dart
Future<void> _analyze() async {
  if (_selectedImage == null) return;  // Validación: necesita imagen

  setState(() {
    _isLoading = true;        // Activar indicador de carga
    _errorMessage = null;     // Limpiar errores previos
    _result = null;           // Limpiar resultados previos
  });

  try {
    final result = await MelanomaService.predict(
      imageFile: _selectedImage!,
      threshold: _threshold,
      mode: _selectedMode,
      notes: _notesController.text,
    );

    setState(() {
      _result = result;       // Guardar resultado exitoso
    });
  } catch (e) {
    _showError("Erreur analyse: $e");
  } finally {
    setState(() => _isLoading = false);  // Siempre desactivar carga
  }
}
```

> **`finally`**: Se ejecuta siempre, haya error o no, garantizando que `_isLoading` vuelva a `false`.

#### 6.6 Métodos Utilitarios (Líneas 478-494)

```dart
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
```

#### 6.7 Método Build Principal (Líneas 496-554)

```dart
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
          _buildDisclaimer(),           // Advertencia médica
          const SizedBox(height: 20),
          _buildImageSection(),          // Sección de imagen
          const SizedBox(height: 20),
          
          // Condicional: mostrar resultados o formulario
          if (_result != null)
            _buildResultsSection()
          else
            _buildFormSection(),
          
          // Indicador de carga
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const Text("Analyse en cours..."),
          ],
          
          // Mensaje de error
          if (_errorMessage != null) ...[
            // Container rojo con error
          ],
        ],
      ),
    ),
  );
}
```

#### 6.8 Widget Disclaimer (Líneas 556-577)

```dart
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
            "Ce logiciel est uniquement destiné à la recherche/éducation. "
            "Il ne remplace pas un diagnostic médical.",
            style: TextStyle(fontSize: 12, color: Colors.amber),
          ),
        ),
      ],
    ),
  );
}
```

> ⚠️ **Importante:** Esta advertencia legal es obligatoria para aplicaciones médicas.

#### 6.9 Widget de Sección de Imagen (Líneas 579-613)

```dart
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
        image: _selectedImage != null
            ? DecorationImage(
                image: FileImage(_selectedImage!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _selectedImage == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                SizedBox(height: 10),
                Text("Appuyez pour ajouter une image"),
              ],
            )
          : null,
    ),
  );
}
```

| Elemento | Descripción |
|----------|-------------|
| `GestureDetector` | Detecta toques del usuario |
| `Container` | Contenedor con dimensiones y decoración fija |
| `DecorationImage` | Muestra la imagen seleccionada como fondo |
| `FileImage` | Widget que carga imagen desde un archivo local |

#### 6.10 Widget Formulario (Líneas 615-695)

```dart
Widget _buildFormSection() {
  return Column(
    children: [
      // Slider de umbral
      Text("Seuil de détection: ${_threshold.toStringAsFixed(2)}"),
      Slider(
        value: _threshold,
        min: 0.3,
        max: 0.7,
        divisions: 40,
        onChanged: (v) => setState(() => _threshold = v),
      ),
      
      // Selector de modo
      SegmentedButton<String>(
        segments: _modeOptions.map((mode) {
          final isRapido = mode.contains('Rápido');
          return ButtonSegment(
            value: mode,
            label: Text(isRapido ? '⚡ Rapide' : '🧠 Précis'),
            icon: Icon(isRapido ? Icons.speed : Icons.psychology),
          );
        }).toList(),
        selected: {_selectedMode},
        onSelectionChanged: (selection) {
          setState(() => _selectedMode = selection.first);
        },
      ),
      
      // Campo de notas
      TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Notes (optionnel)',
          prefixIcon: Icon(Icons.note),
        ),
      ),
      
      // Botón de análisis
      FilledButton.icon(
        onPressed: (_selectedImage == null || _isLoading) ? null : _analyze,
        icon: const Icon(Icons.analytics),
        label: const Text("LANCER L'ANALYSE"),
      ),
    ],
  );
}
```

#### 6.11 Widget de Resultados (Líneas 698-1054)

Esta sección muestra los resultados del análisis:

**Tarjeta de Diagnóstico Principal (Líneas 741-787):**

```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
  decoration: BoxDecoration(
    color: isMalignant
        ? Colors.red.shade900.withOpacity(0.8)
        : Colors.green.shade900.withOpacity(0.8),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: isMalignant ? Colors.red.withOpacity(0.4) : Colors.green.withOpacity(0.4),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    children: [
      Icon(
        isMalignant ? Icons.warning_amber_rounded : Icons.check_circle_outline,
        size: 64,
        color: Colors.white,
      ),
      Text(
        diagnosis.toUpperCase(),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      Text("Confiance IA: ${(confidence * 100).toStringAsFixed(1)}%"),
    ],
  ),
)
```

**Botón de Edición de Contornos (Líneas 818-847):**

```dart
if (res.contours != null && res.contours!.isNotEmpty && _selectedImage != null)
  OutlinedButton.icon(
    icon: const Icon(Icons.edit_location_alt),
    label: const Text("MODIFIER LA SEGMENTATION"),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BorderEditorPage(
            imageFile: _selectedImage!,
            initialContours: res.contours!,
            mmPerPixel: 0.0,
          ),
        ),
      );
    },
  ),
```

#### 6.12 Helpers de UI (Líneas 1056-1230)

```dart
// Fila de probabilidad con barra de progreso
Widget _buildProbabilityRow(String label, dynamic value) {
  double prob = value is num ? value.toDouble() : 0.0;
  Color color = label.contains("mélanome") ? Colors.redAccent : Colors.greenAccent;
  
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text("${(prob * 100).toStringAsFixed(1)}%", style: TextStyle(color: color)),
        ],
      ),
      LinearProgressIndicator(
        value: prob,
        color: color,
        minHeight: 8,
      ),
    ],
  );
}

// Fila de información con icono
Widget _buildInfoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 20, color: Colors.white70),
      const SizedBox(width: 12),
      Text(label),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

// Construcción de imagen desde URL o Base64
Widget _buildImageFromSrc(String src) {
  if (src.startsWith('data:image')) {
    // Es Base64 - decodificar y mostrar
    final base64Str = src.split(',').last;
    return Image.memory(base64Decode(base64Str), fit: BoxFit.cover, height: 160);
  }
  
  // Es URL - cargar desde red con FutureBuilder
  String fullUrl = src;
  if (!src.startsWith('http')) {
    final baseUrl = "https://oscar2525mv-melanoma.hf.space";
    fullUrl = src.startsWith('/file=') 
        ? "$baseUrl$src" 
        : "$baseUrl/file=$src";
  }
  
  return FutureBuilder<http.Response>(
    future: http.get(Uri.parse(fullUrl)),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _buildErrorBox(fullUrl, "Error: ${snapshot.error}");
      }
      return Image.memory(snapshot.data!.bodyBytes, fit: BoxFit.cover);
    },
  );
}
```

---

## Archivo: border_editor.dart

Este archivo contiene el **editor visual de contornos** con **333 líneas** de código.

---

### Clase BorderEditorPage (Líneas 7-21)

```dart
class BorderEditorPage extends StatefulWidget {
  final File imageFile;                    // Archivo de imagen a editar
  final List<List<double>> initialContours; // Contornos iniciales [x, y]
  final double mmPerPixel;                 // Escala mm/pixel (opcional)

  const BorderEditorPage({
    super.key,
    required this.imageFile,
    required this.initialContours,
    this.mmPerPixel = 0.0,
  });

  @override
  State<BorderEditorPage> createState() => _BorderEditorPageState();
}
```

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `imageFile` | `File` | requerido | Imagen sobre la que editar |
| `initialContours` | `List<List<double>>` | requerido | Puntos [x,y] del contorno |
| `mmPerPixel` | `double` | `0.0` | Factor de conversión a milímetros |

---

### Estado del Editor (Líneas 23-271)

#### Variables de Estado (Líneas 23-35)

```dart
class _BorderEditorPageState extends State<BorderEditorPage> {
  // Información de la imagen
  ui.Image? _image;            // Imagen decodificada
  bool _isImageLoaded = false; // Flag de carga completa

  // Estado del editor
  late List<Offset> _points;   // Puntos del contorno en coordenadas imagen
  int? _draggedPointIndex;     // Índice del punto que se está arrastrando

  // Métricas calculadas
  double _areaPx = 0;          // Área en píxeles cuadrados
  double _diameterPx = 0;      // Diámetro equivalente en píxeles
```

#### Inicialización (Líneas 37-45)

```dart
@override
void initState() {
  super.initState();
  _loadImage();
  // Convertir List<List<double>> a List<Offset>
  _points = widget.initialContours.map((e) => Offset(e[0], e[1])).toList();
  _recalculateMetrics();
}
```

> **`Offset`**: Clase de Flutter que representa un punto 2D con propiedades `dx` (x) y `dy` (y).

#### Carga de Imagen (Líneas 47-55)

```dart
Future<void> _loadImage() async {
  final data = await widget.imageFile.readAsBytes();  // Leer bytes
  final codec = await ui.instantiateImageCodec(data); // Crear codec
  final frame = await codec.getNextFrame();            // Obtener frame
  setState(() {
    _image = frame.image;      // Guardar imagen decodificada
    _isImageLoaded = true;
  });
}
```

#### Fórmula del Shoelace (Líneas 57-81)

La **Fórmula del Shoelace** (o Fórmula del Agujeta) calcula el área de un polígono dado sus vértices:

```dart
void _recalculateMetrics() {
  if (_points.isEmpty) {
    _areaPx = 0;
    _diameterPx = 0;
    return;
  }

  // Fórmula del Shoelace para calcular área
  double area = 0.0;
  for (int i = 0; i < _points.length; i++) {
    final p1 = _points[i];
    final p2 = _points[(i + 1) % _points.length];  // Punto siguiente (circular)
    area += p1.dx * p2.dy;   // x1 * y2
    area -= p1.dy * p2.dx;   // - y1 * x2
  }
  area = area.abs() / 2.0;   // Valor absoluto / 2

  // Diámetro equivalente (diámetro de círculo con misma área)
  double diameter = 2 * sqrt(area / pi);  // d = 2 * sqrt(A/π)

  setState(() {
    _areaPx = area;
    _diameterPx = diameter;
  });
}
```

**Fórmula matemática:**

$$A = \frac{1}{2} \left| \sum_{i=0}^{n-1} (x_i \cdot y_{i+1} - y_i \cdot x_{i+1}) \right|$$

#### Manejo de Gestos (Líneas 83-138)

```dart
void _handleDragStart(DragStartDetails details, Size displaySize, Rect imageRect) {
  if (!_isImageLoaded || _image == null) return;

  // Convertir toque a coordenadas de imagen
  final localPos = details.localPosition;
  final imagePos = _localToImage(localPos, displaySize, imageRect);

  // Encontrar punto más cercano dentro de radio de toque
  final scale = imageRect.width / _image!.width;
  final touchRadius = 25.0 / scale;  // 25 píxeles de pantalla

  double minDist = double.infinity;
  int? closestIndex;

  for (int i = 0; i < _points.length; i++) {
    final dist = (imagePos - _points[i]).distance;
    if (dist < minDist && dist < touchRadius) {
      minDist = dist;
      closestIndex = i;
    }
  }

  setState(() {
    _draggedPointIndex = closestIndex;
  });
}

void _handleDragUpdate(DragUpdateDetails details, Size displaySize, Rect imageRect) {
  if (_draggedPointIndex == null) return;

  final imagePos = _localToImage(details.localPosition, displaySize, imageRect);

  setState(() {
    _points[_draggedPointIndex!] = imagePos;  // Actualizar posición del punto
    _recalculateMetrics();                     // Recalcular área/diámetro
  });
}

void _handleDragEnd(DragEndDetails details) {
  setState(() {
    _draggedPointIndex = null;  // Liberar punto
  });
}
```

#### Transformación de Coordenadas (Líneas 140-146)

```dart
Offset _localToImage(Offset local, Size displaySize, Rect imageRect) {
  // Offset relativo al Rect de la imagen
  final dx = (local.dx - imageRect.left) / imageRect.width * _image!.width;
  final dy = (local.dy - imageRect.top) / imageRect.height * _image!.height;
  return Offset(dx, dy);
}
```

Esta función convierte coordenadas de **pantalla** a coordenadas de **imagen**:

```
Coordenada Pantalla → Normalizado (0-1) → Coordenada Imagen
```

#### Método Build (Líneas 148-253)

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Éditeur de Segmentation"),
      actions: [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
    backgroundColor: Colors.black,
    body: !_isImageLoaded
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (ctx, constraints) {
              // Calcular dimensiones para BoxFit.contain
              final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
              final src = Size(_image!.width.toDouble(), _image!.height.toDouble());
              
              final fittedSizes = applyBoxFit(BoxFit.contain, src, displaySize);
              final destSize = fittedSizes.destination;
              
              // Centrar imagen
              final dx = (displaySize.width - destSize.width) / 2;
              final dy = (displaySize.height - destSize.height) / 2;
              final imageRect = Rect.fromLTWH(dx, dy, destSize.width, destSize.height);

              return Stack(
                children: [
                  // Área interactiva con CustomPaint
                  GestureDetector(
                    onPanStart: (d) => _handleDragStart(d, displaySize, imageRect),
                    onPanUpdate: (d) => _handleDragUpdate(d, displaySize, imageRect),
                    onPanEnd: _handleDragEnd,
                    child: CustomPaint(
                      size: displaySize,
                      painter: _EditorPainter(
                        image: _image!,
                        points: _points,
                        imageRect: imageRect,
                      ),
                    ),
                  ),
                  
                  // Tarjeta flotante con métricas
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Colors.black87,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildMetricRow("Aire (px)", _areaPx.toStringAsFixed(0)),
                            _buildMetricRow("Diamètre (px)", _diameterPx.toStringAsFixed(1)),
                            if (widget.mmPerPixel > 0)
                              _buildMetricRow(
                                "Diamètre (mm)",
                                (_diameterPx * widget.mmPerPixel).toStringAsFixed(2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
  );
}
```

---

### CustomPainter _EditorPainter (Líneas 274-332)

Esta clase se encarga de **dibujar** la imagen y el polígono de contorno.

```dart
class _EditorPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final Rect imageRect;

  _EditorPainter({
    required this.image,
    required this.points,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar imagen
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.contain,
    );

    // 2. Dibujar polígono
    if (points.isNotEmpty) {
      final scaleX = imageRect.width / image.width;
      final scaleY = imageRect.height / image.height;

      // Mapear coordenadas de imagen a pantalla
      final screenPoints = points.map((p) {
        return Offset(
          imageRect.left + p.dx * scaleX,
          imageRect.top + p.dy * scaleY,
        );
      }).toList();

      // Dibujar líneas del contorno
      final paintPath = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path()..addPolygon(screenPoints, true);
      canvas.drawPath(path, paintPath);

      // 3. Dibujar puntos de control
      final paintDot = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.fill;

      for (var p in screenPoints) {
        canvas.drawCircle(p, 4.0, paintDot);  // Radio de 4 píxeles
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

| Elemento Visual | Color | Descripción |
|-----------------|-------|-------------|
| Líneas del contorno | `Colors.blueAccent` | Líneas azules conectando los puntos |
| Puntos de control | `Colors.yellowAccent` | Círculos amarillos que el usuario puede arrastrar |

---

## Glosario de Términos

| Término | Descripción |
|---------|-------------|
| **StatelessWidget** | Widget inmutable que no mantiene estado. Se reconstruye completamente cuando sus parámetros cambian |
| **StatefulWidget** | Widget que mantiene estado mutable. Puede actualizarse sin recrearse |
| **setState()** | Método que notifica a Flutter que el estado cambió y debe reconstruirse la UI |
| **Future** | Representa un valor que estará disponible en el futuro (operación asíncrona) |
| **async/await** | Sintaxis para trabajar con Futures de forma secuencial y legible |
| **GestureDetector** | Widget que detecta gestos del usuario (toques, arrastres, etc.) |
| **CustomPainter** | Clase para dibujo personalizado sobre un Canvas |
| **BoxFit.contain** | Modo de ajuste que escala para caber completamente manteniendo proporciones |
| **SSE (Server-Sent Events)** | Protocolo para que el servidor envíe eventos al cliente en tiempo real |
| **Grad-CAM** | Gradient-weighted Class Activation Mapping - técnica de visualización de IA |
| **Shoelace Formula** | Algoritmo matemático para calcular el área de un polígono |

---

## Diagramas de Flujo

### Flujo de Análisis de Imagen

```
┌──────────────────┐
│  Usuario toca    │
│  "Añadir imagen" │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ showModalBottom- │
│ Sheet (Cámara/   │
│ Galería)         │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  ImagePicker     │
│  pickImage()     │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  setState()      │
│  _selectedImage  │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  Usuario ajusta  │
│  parámetros      │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  Toca "LANCER    │
│  L'ANALYSE"      │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  _analyze()      │
│  _isLoading=true │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  MelanomaService │
│  .predict()      │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  POST /call/     │
│  predict_ui      │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  Obtener         │
│  event_id        │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  GET SSE stream  │
│  /predict_ui/    │
│  {event_id}      │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  Parsear SSE     │
│  data: [...]     │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  PredictResult   │
│  .fromList()     │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  setState()      │
│  _result = res   │
│  _isLoading=false│
└────────┬─────────┘
         ▼
┌──────────────────┐
│  _buildResults-  │
│  Section()       │
│  Mostrar UI      │
└──────────────────┘
```

### Flujo de Edición de Contornos

```
┌──────────────────┐
│  Usuario toca    │
│  "MODIFIER LA    │
│  SEGMENTATION"   │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  Navigator.push  │
│  BorderEditorPage│
└────────┬─────────┘
         ▼
┌──────────────────┐
│  initState()     │
│  _loadImage()    │
│  Convertir       │
│  contornos a     │
│  List<Offset>    │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  LayoutBuilder   │
│  calcular        │
│  imageRect       │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  CustomPaint     │
│  _EditorPainter  │
│  dibujar imagen  │
│  + polígono      │
└────────┬─────────┘
         ▼
┌──────────────────┐     ┌─────────────────┐
│  GestureDetector │────▶│ _handleDragStart│
│  onPanStart      │     │ encontrar punto │
└────────┬─────────┘     │ más cercano     │
         │               └─────────────────┘
         ▼
┌──────────────────┐     ┌─────────────────┐
│  onPanUpdate     │────▶│ _handleDragUpdate│
│  (arrastrando)   │     │ actualizar punto│
└────────┬─────────┘     │ recalcular área │
         │               └─────────────────┘
         ▼
┌──────────────────┐
│  onPanEnd        │
│  liberar punto   │
└────────┬─────────┘
         ▼
┌──────────────────┐
│  _EditorPainter  │
│  redibujar con   │
│  nueva posición  │
└──────────────────┘
```

---

## 📝 Notas Finales

### Dependencias Utilizadas

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0                    # Cliente HTTP
  image_picker: ^1.0.4            # Selector de imágenes
  permission_handler: ^11.0.0     # Gestión de permisos
  shared_preferences: ^2.2.2      # Almacenamiento local
```

### Consideraciones de Rendimiento

1. **Imágenes**: Se redimensionan a máximo 1024x1024 para reducir tiempo de carga
2. **SSE Streaming**: Permite recibir resultados progresivos sin bloquear la UI
3. **CustomPainter**: Eficiente para dibujo 2D con repintado controlado

### Consideraciones de UX

1. **Advertencia Médica**: Siempre visible para cumplir regulaciones
2. **Feedback Visual**: Indicadores de carga claros durante el análisis
3. **Colores Semafóricos**: Verde (benigno) / Rojo (maligno) para fácil interpretación

---

*Documento generado automáticamente. Para más información, consulte el repositorio del proyecto.*
