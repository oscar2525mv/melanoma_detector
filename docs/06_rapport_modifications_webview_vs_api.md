# Rapport : Transition WebView vers API Native

Ce rapport détaille les modifications majeures effectuées pour passer d'une application basée sur une `WebView` à une application Flutter **Native** connectée à l'API Gradio.

## 1. Modifications Effectuées

### Dépendances (`pubspec.yaml`)
*   **Suppression** : `webview_flutter`, `webview_flutter_android` (Lourds, non nécessaires pour l'API).
*   **Ajout** : `http` (Pour les requêtes API POST/GET).
*   **Maintien** : `image_picker`, `permission_handler` (Nécessaires pour la sélection d'images).

### Code Principal (`lib/main.dart`)
Le code a été entièrement réécrit.
*   **Avant (WebView)** : On chargeait une URL. On injectait du Javascript pour cacher les divs HTML indésirables. On subissait le design du site web.
*   **Après (Natif)** :
    *   **Service API (`MelanomaService`)** : Une classe dédiée gère la communication avec Hugging Face. Elle convertit l'image en Base64, envoie le JSON, et écoute le flux SSE (Server-Sent Events) pour la réponse.
    *   **Modèle de Données (`PredictResult`)** : Une classe typée pour stocker proprement les probabilités, les images (base64/url) et le rapport texte.
    *   **Interface UI (`MelanomaNativePage`)** : Une interface 100% Flutter (Material 3). Nous avons le contrôle total sur les boutons, les couleurs, les cartes de résultats et les messages d'erreur.

## 2. Comparatif : WebView vs API Native

| Caractéristique | Approche WebView (Ancienne) | Approche API Native (Actuelle) |
| :--- | :--- | :--- |
| **Expérience Utilisateur** | **Moyenne**. On sent que c'est un site web (scroll, chargement, styles non natifs). | **Excellente**. Fluide, animations natives, respect du thème sombre du téléphone. |
| **Contrôle UI** | **Faible**. Nécessite du "hacking" CSS pour cacher les éléments. Fragile si le site change. | **Total**. On dessine chaque pixel. On peut afficher les probabilités avec des barres de progression personnalisées. |
| **Gestion des Erreurs** | **Opaque**. Si le site plante ou charge mal, l'utilisateur voit une page web d'erreur ou blanche. | **Précise**. On peut détecter une erreur 404, 500 ou de réseau et afficher un message clair ("Erreur Serveur", "Pas d'internet"). |
| **Performance** | **Lourde**. Charge tout un moteur de rendu web + JS + CSS. | **Légère**. Uniquement des requêtes JSON et téléchargement d'images. |
| **Accès aux Données** | **Visuel seulement**. On ne peut "lire" les chiffres que si on fait du scraping complexe. | **Brut**. On reçoit les variables (ex: `0.758`) directement, permettant de faire des calculs ou des affichages conditionnels. |

## Conclusion
Le passage au natif offre une application beaucoup plus robuste, maintenable et professionnelle. Bien que plus complexe à mettre en place initialement (il faut comprendre l'API), le résultat final est largement supérieur pour l'utilisateur final.
