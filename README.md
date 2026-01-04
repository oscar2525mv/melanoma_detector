# 🔬 Détecteur de Mélanome

Application Flutter pour la détection de mélanomes utilisant l'intelligence artificielle. Se connecte à une API Gradio hébergée sur Hugging Face pour l'analyse d'images avec visualisation Grad-CAM et édition interactive des contours.

## 📱 Fonctionnalités

- **Capture d'image** : Prise de photo directe ou sélection depuis la galerie
- **Analyse IA** : Détection de mélanome via modèles d'apprentissage profond
- **Visualisation Grad-CAM** : Carte de chaleur montrant les zones d'attention du modèle
- **Segmentation** : Délimitation automatique de la lésion
- **Mode Ensemble** : Analyse précise utilisant plusieurs modèles IA avec vote majoritaire
- **Édition des contours** : Ajustement interactif des bordures de la lésion avec calcul en temps réel

## 🚀 Installation

### Prérequis

- Flutter SDK (≥ 3.0)
- Android Studio ou VS Code avec extensions Flutter
- Émulateur Android ou appareil physique

### Étapes

```bash
# Cloner le dépôt
git clone https://github.com/oscar2525mv/melanoma_detector.git
cd melanoma_detector

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

## 🏗️ Architecture

```
lib/
├── main.dart           # Application principale et service API
└── border_editor.dart  # Éditeur interactif de contours
```

### Composants principaux

| Composant | Description |
|-----------|-------------|
| `MelanomaService` | Service API pour communiquer avec Gradio |
| `PredictResult` | Modèle de données pour les résultats d'analyse |
| `BorderEditorPage` | Widget d'édition interactive des contours |
| `_EditorPainter` | CustomPainter pour le rendu des polygones |

## 🔌 API Gradio

L'application se connecte à l'endpoint :
```
https://oscar2525mv-melanoma.hf.space/gradio_api/call/predict_ui
```

### Paramètres d'entrée (4)

| Paramètre | Type | Description |
|-----------|------|-------------|
| `image` | Base64 | Image encodée en base64 |
| `threshold` | Float (0.3-0.7) | Seuil de détection |
| `mode` | String | "Rápido (Solo Local)" ou "Preciso (Ensemble/Comité)" |
| `notes` | String | Notes optionnelles |

### Réponse JSON

```json
{
  "prediccion_final": "Malignant",
  "prob_promedio": 0.997,
  "detalle_modelos": {
    "BasicCNN (Local)": 0.999,
    "Melanoma-Cancer-Image-classification": 0.993
  },
  "tamano": {
    "area_px": 546409,
    "diam_px": 834.09
  },
  "contornos": [[[x, y], ...]]
}
```

## 📊 Modes d'analyse

### ⚡ Mode Rapide (Solo Local)
- Utilise uniquement le modèle local BasicCNN
- Temps de réponse rapide
- Idéal pour un premier dépistage

### 🧠 Mode Précis (Ensemble/Comité)
- Combine plusieurs modèles IA
- Affiche le détail de chaque modèle avec sa probabilité
- Résultat par vote majoritaire pondéré
- Recommandé pour une analyse approfondie

## 🎨 Éditeur de Contours

L'éditeur interactif permet de :
- Visualiser les contours détectés sur l'image originale
- Déplacer les points par glisser-déposer
- Recalculer l'aire et le diamètre en temps réel (formule de Shoelace)

## ⚠️ Avertissement

> **Ce logiciel est destiné uniquement à la recherche et à l'éducation.**
> Il ne remplace en aucun cas un diagnostic médical professionnel.
> Consultez toujours un dermatologue pour tout doute concernant une lésion cutanée.

## 📦 Dépendances

```yaml
dependencies:
  flutter:
  http: ^1.1.0
  image_picker: ^1.0.4
  permission_handler: ^11.0.1
  shared_preferences: ^2.2.2
```

## 📄 Licence

Ce projet est développé dans un cadre éducatif.

## 👨‍💻 Auteur

Développé avec Flutter et ❤️
