# Plan d'Implémentation : Visualiseur Multi-Modèle de Détection de Mélanome

Application Flutter permettant de basculer entre différents modèles de détection de mélanome hébergés sur Hugging Face Spaces.

## Aperçu

L'application transformera automatiquement les URLs Hugging Face en URLs directes `.hf.space`, permettra à l'utilisateur de sélectionner parmi plusieurs modèles pré-configurés, d'en ajouter dynamiquement, et offrira une expérience native en masquant les éléments d'interface Hugging Face.

---

## Règle de Transformation d'URL

```
Entrée  : https://huggingface.co/spaces/UTILISATEUR/REPO
Sortie  : https://UTILISATEUR-REPO.hf.space
```

**Exemple :**
- `https://huggingface.co/spaces/sapnashettyy/melanoma-detector`
- → `https://sapnashettyy-melanoma-detector.hf.space`

---

## Modèles Initiaux

| Nom du Modèle | URL Originale | URL Transformée |
|---------------|---------------|-----------------|
| Melanoma Detector (sapnashettyy) | `https://huggingface.co/spaces/sapnashettyy/melanoma-detector` | `https://sapnashettyy-melanoma-detector.hf.space` |
| Melanoma (ish028792) | `https://huggingface.co/spaces/ish028792/melanoma` | `https://ish028792-melanoma.hf.space` |
| Melanoma Detection System | `https://huggingface.co/spaces/dehannoor3199/melanoma-detection-system` | `https://dehannoor3199-melanoma-detection-system.hf.space` |
| Melanoma Detector 2 | `https://huggingface.co/spaces/sapnashettyy/melanoma-detector2` | `https://sapnashettyy-melanoma-detector2.hf.space` |
| Melanoma (Nachosanchezz) | `https://huggingface.co/spaces/Nachosanchezz/Melanoma` | `https://Nachosanchezz-Melanoma.hf.space` |

---

## Structure du Projet

```
melanoma_detector/
├── lib/
│   └── main.dart                 # Code principal de l'application
├── android/
│   └── app/
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml    # Permissions Android
│               └── res/
│                   └── xml/
│                       └── file_paths.xml # FileProvider config
├── pubspec.yaml                  # Dépendances Flutter
└── docs/                         # Documentation
```

---

## Fichiers à Créer

### 1. pubspec.yaml

Configuration du projet avec les dépendances :
- `webview_flutter` et `webview_flutter_android` pour le WebView
- `permission_handler` pour les permissions caméra/galerie
- `image_picker` pour la sélection d'images
- `shared_preferences` pour la persistance des modèles ajoutés

### 2. lib/main.dart

Fichier principal contenant :

1. **Classe `MelanomaModel`** - Modèle de données avec :
   - `name` : Nom affiché
   - `originalUrl` : URL Hugging Face originale
   - `directUrl` : URL transformée (calculée automatiquement)

2. **Fonction `transformHuggingFaceUrl()`** - Transformation automatique :
   ```dart
   // Entrée : https://huggingface.co/spaces/USER/REPO
   // Sortie : https://USER-REPO.hf.space
   ```

3. **Interface de sélection de modèles** - Drawer latéral ergonomique avec :
   - Liste des modèles disponibles
   - Indicateur du modèle actif
   - Bouton d'ajout de nouveau modèle

4. **Boîte de dialogue d'ajout dynamique** - Permet à l'utilisateur d'entrer une URL originale

5. **NavigationDelegate restrictif** - Bloque toute navigation hors du domaine `.hf.space` actif

6. **Injection CSS/JS avancée** - Masque :
   - Headers et footers Hugging Face
   - Boutons "Show API"
   - Bannières de chargement
   - Navigation Gradio

### 3. AndroidManifest.xml

Permissions Android requises :
- `INTERNET`
- `CAMERA`
- `READ_EXTERNAL_STORAGE` (Android < 13)
- `READ_MEDIA_IMAGES` (Android 13+)

### 4. file_paths.xml

Configuration FileProvider pour compatibilité image_picker.

---

## Plan de Vérification

### Tests Automatisés
- Analyse statique avec `flutter analyze`
- Compilation avec `flutter build apk --debug`

### Vérification Manuelle
- Test de la fonction de transformation d'URL
- Test du changement de modèle
- Test de l'ajout dynamique de modèle
- Test du blocage de navigation
