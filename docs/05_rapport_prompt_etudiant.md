# Prompt "Projet Étudiant" : Refactoring vers API Native Gradio

## Contexte
J'ai développé une application Flutter qui utilise actuellement une `WebView` pour afficher un "Space" Hugging Face de détection de mélanome. Ça fonctionne, mais ce n'est pas optimisé : l'expérience utilisateur n'est pas fluide, le design n'est pas natif, et je dépends trop de l'interface web.

## Mon Objectif
Je veux **supprimer complètement la WebView** et connecter mon application Flutter directement à l'**API Gradio** de ce Space. Je veux une interface utilisateur 100% native Flutter (Material Design 3).

## URL du Space
Le modèle est hébergé ici : `https://huggingface.co/spaces/Nachosanchezz/Melanoma`
L'endpoint API semble être : `https://nachosanchezz-melanoma.hf.space/gradio_api/call/predict_ui`

## Ce que je te demande

Peux-tu m'aider à refactoriser mon code (`main.dart`) pour faire ceci :

1.  **Supprimer la WebView** : Enlever le package `webview_flutter`.
2.  **Intégration API (`http`)** :
    *   Créer un service qui envoie l'image sélectionnée par l'utilisateur à l'API.
    *   L'image doit être convertie en Base64.
    *   Il faut gérer la réponse JSON (probabilités, images Grad-CAM/Segmentation).
3.  **Interface Native** :
    *   Refaire l'écran principal. Au lieu d'une page web, je veux voir :
        *   Un bouton pour choisir une photo.
        *   Des curseurs pour régler les paramètres (Seuil, mm/pixel).
        *   Une belle carte de résultat qui s'affiche après l'analyse (Rouge pour maligne, Vert pour bénin).
4.  **Affichage des Résultats** :
    *   Afficher clairement le diagnostic et le pourcentage de confiance.
    *   Afficher les images retournées par l'API (Grad-CAM etc.).

C'est un projet étudiant, donc le code doit être clair et bien commenté pour que je puisse expliquer comment j'ai parsé la réponse de l'API.

Merci d'avance pour ton aide !
