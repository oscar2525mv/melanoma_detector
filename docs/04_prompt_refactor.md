# Prompt : Refactorisation vers API Native (Gradio/Hugging Face)

**Rôle :** Expert Senior Flutter & Mobile Architecture.

**Contexte :**
Je dispose d'une application Flutter (`melanoma_detector`) qui utilise actuellement une `WebView` pour afficher un Space Hugging Face. Je souhaite **abandonner complètement l'approche WebView** pour passer à une interface **100% Native Flutter** qui communique avec le backend via des requêtes HTTP (API REST/Gradio).

**Objectif :**
Modifier le projet existant (notamment `lib/main.dart` et `pubspec.yaml`) pour implémenter la logique suivante :
1.  L'utilisateur sélectionne une image (Gallerie ou Caméra).
2.  L'utilisateur configure les paramètres (Seuil, mm/pixel, Objectif, Notes).
3.  L'application envoie l'image et les paramètres à l'API Gradio.
4.  L'application affiche les résultats reçus (Images traitées, JSON, Textes) nativement.

**Détails de l'API (Gradio) :**
- **Endpoint :** `https://nachosanchezz-melanoma.hf.space/gradio_api/call/predict_ui`
- **Méthode :** POST pour initier, puis GET/Stream pour récupérer le résultat via `EVENT_ID`.
- **Format Payload (JSON) :**
  ```json
  {
    "data": [
      {
        "path": "URL_OU_BASE64_IMAGE",
        "meta": {"_type": "gradio.FileData"}
      },
      0.5,                  // Seuil (float)
      0,                    // mm_per_pixel (int/float)
      "Balance",            // Objectif (String: 'Detección temprana (sensibilidad)', 'Balance', 'Seguridad diagnóstica (especificidad)')
      "Notes optionnelles"  // Notes (String)
    ]
  }
  ```
- **Réponse Attendue :** Une liste contenant : [Image Grad-CAM, Image Segmentation, JSON Résultats, HTML/Markdown, File ZIP, HTML/Markdown].

**Tâches à réaliser :**

1.  **Mise à jour de `pubspec.yaml` :**
    - Retirer `webview_flutter` et dépendances associées.
    - Ajouter le package `http`.
    - Conserver `image_picker`, `permission_handler` (et `shared_preferences` si utile).

2.  **Refonte de `lib/main.dart` :**
    - Créer une interface utilisateur native et moderne (Material 3).
    - **Formulaire :**
        - Widget de sélection d'image (Placeholder si vide, Preview si sélectionnée).
        - Slider pour le "Seuil" (0.0 à 1.0).
        - Dropdown pour "Objectif" (les 3 choix).
        - Champ texte pour "Notes".
        - Bouton "Analyser".
    - **Logique API (`MelanomaService`) :**
        - Convertir l'image sélectionnée en Base64.
        - Envoyer la requête POST.
        - Gérer la boucle de réponse Gradio (récupérer l'`EVENT_ID` et poller/écouter le résultat).
    - **Affichage des Résultats :**
        - Afficher les images retournées (décoder Base64 ou URL).
        - Afficher le JSON de diagnostic de manière lisible.

**Contraintes :**
- Le code doit être robuste (gestion des erreurs HTTP, chargement).
- L'interface doit être propre et professionnelle ("Premium UI").
- Tout le code doit être en Dart (pas de Python/JS).
- Utiliser `Convert` pour le Base64.

**Livrable :**
- Le code complet de `pubspec.yaml`.
- Le code complet de `lib/main.dart`.
