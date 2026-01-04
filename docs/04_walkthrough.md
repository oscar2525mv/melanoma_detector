# Walkthrough : Visualiseur Multi-Modèle de Détection de Mélanome

## ✅ Résumé du Travail Accompli

Application Flutter complète permettant de visualiser et basculer entre plusieurs modèles de détection de mélanome hébergés sur Hugging Face Spaces.

---

## 📁 Fichiers Créés

| Fichier | Description |
|---------|-------------|
| `pubspec.yaml` | Configuration avec dépendances WebView, permissions, image_picker |
| `lib/main.dart` | Code principal avec toute la logique de l'application |
| `android/app/src/main/AndroidManifest.xml` | Permissions Android (Caméra, Galerie, Internet) |
| `android/app/build.gradle.kts` | Configuration Gradle avec résolution de conflit activity |
| `android/app/src/main/res/xml/file_paths.xml` | Configuration FileProvider pour image_picker |

---

## 🔧 Fonctionnalités Implémentées

### 1. Transformation d'URL Hugging Face

```dart
/// Transforme une URL Hugging Face originale en URL directe .hf.space
/// Entrée : https://huggingface.co/spaces/UTILISATEUR/REPO
/// Sortie : https://UTILISATEUR-REPO.hf.space
static String transformHuggingFaceUrl(String originalUrl) {
  // Si c'est déjà une URL directe, la retourner telle quelle
  if (originalUrl.contains('.hf.space')) {
    return originalUrl;
  }

  // Pattern: https://huggingface.co/spaces/USER/REPO
  final regex = RegExp(r'https?://huggingface\.co/spaces/([^/]+)/([^/\s]+)');
  final match = regex.firstMatch(originalUrl);

  if (match != null) {
    final user = match.group(1)!;
    final repo = match.group(2)!;
    return 'https://$user-$repo.hf.space';
  }

  // Si le format n'est pas reconnu, retourner l'URL originale
  return originalUrl;
}
```

### 2. Liste des Modèles Pré-chargés

| Modèle | URL Transformée |
|--------|-----------------|
| Melanoma Detector (sapnashettyy) | `sapnashettyy-melanoma-detector.hf.space` |
| Melanoma (ish028792) | `ish028792-melanoma.hf.space` |
| Melanoma Detection System | `dehannoor3199-melanoma-detection-system.hf.space` |
| Melanoma Detector 2 | `sapnashettyy-melanoma-detector2.hf.space` |
| Melanoma (Nachosanchezz) | `Nachosanchezz-Melanoma.hf.space` |

### 3. Menu de Sélection de Modèles

- Drawer latéral avec liste des modèles
- Indicateur du modèle actif (icône check)
- Bouton d'ajout dynamique de modèle
- Design Material 3 avec thème sombre violet

### 4. Ajout Dynamique de Modèles

- Dialogue pour entrer une URL Hugging Face originale
- Transformation automatique en URL directe
- Persistance automatique via SharedPreferences
- Validation du format d'URL

### 5. Blocage de Navigation (Mode Kiosque)

```dart
onNavigationRequest: (NavigationRequest request) {
  final currentDomain = _extractDomain(_currentModel.directUrl);
  if (request.url.contains(currentDomain) || 
      request.url.startsWith(_currentModel.directUrl)) {
    return NavigationDecision.navigate;
  }
  debugPrint('Navigation bloquée vers: ${request.url}');
  return NavigationDecision.prevent;
}
```

### 6. Injection CSS/JS pour Apparence Native

Le code injecte un CSS qui masque automatiquement :
- ✅ Headers et footers Hugging Face
- ✅ Boutons "Show API" et "Built with Gradio"
- ✅ Liens de branding Gradio
- ✅ Éléments de navigation Gradio
- ✅ Amélioration du style de scrollbar

### 7. Gestion des Permissions Android

```dart
Future<void> _requestPermissions() async {
  await Permission.camera.request();
  if (Platform.isAndroid) {
    // Android 13+ utilise READ_MEDIA_IMAGES
    if (await Permission.photos.status.isDenied) {
      await Permission.photos.request();
    }
    // Android < 13 utilise READ_EXTERNAL_STORAGE
    if (await Permission.storage.status.isDenied) {
      await Permission.storage.request();
    }
  }
}
```

---

## 🧪 Vérification

### Analyse Statique
```bash
$ flutter analyze
Analyzing melanoma_detector...
No issues found! (ran in 1.2s)
```

### Dépendances
```bash
$ flutter pub get
Resolving dependencies...
Got dependencies!
```

---

## 🚀 Comment Lancer l'Application

```bash
# Se placer dans le répertoire du projet
cd melanoma_detector

# Télécharger les dépendances
flutter pub get

# Lancer sur Android (émulateur ou appareil connecté)
flutter run

# Ou construire l'APK
flutter build apk
```

---

## 📱 Interface Utilisateur

L'application utilise **Material Design 3** avec un thème sombre violet. Elle comprend :

1. **AppBar** - Affiche le nom du modèle actif + boutons Refresh/Aide
2. **Drawer** - Menu latéral pour sélection et ajout de modèles
3. **WebView** - Affichage plein écran du modèle Hugging Face
4. **FAB** - Boutons flottants pour navigation avant/arrière
5. **Overlay de chargement** - Animation pendant le chargement des pages
6. **Dialogue d'aide** - Instructions d'utilisation

---

## ⚠️ Avertissement

> Cette application est à but **éducatif uniquement**. Les résultats de détection de mélanome fournis par les modèles ne remplacent **pas** un avis médical professionnel. Consultez toujours un dermatologue pour tout diagnostic.

---

## 📂 Emplacement du Projet

```
c:\Users\martv\Proyect\projet_webview\HF_WebView\melanoma_detector\
```
