# Rapport Technique : Complications liées aux Images

Ce rapport analyse les problèmes rencontrés lors de l'affichage des images de résultat (Grad-CAM et Segmentation) et les solutions apportées.

## 1. Le Problème Initial
Après avoir basculé vers l'API, les images ne s'affichaient pas.
*   **Symptôme** : Un cadre d'erreur apparaissait à la place de l'image.
*   **Erreur** : `DecodeErr. Body: <!DOCTYPE html>...`

Cela indiquait que l'application ne téléchargeait pas une image (JPG/PNG), mais recevait une **page HTML** (probablement une page 404 "Not Found" ou 403 "Forbidden").

## 2. L'Origine du Problème : La Construction d'URL
L'API Gradio renvoie les chemins des fichiers générés. Il y a deux formats possibles dans la réponse JSON :
1.  **Format Path** : `{"path": "/tmp/gradio/..."}`. C'est un chemin local sur le serveur.
2.  **Format URL** : `{"url": "https://.../file=/tmp/..."}`. C'est l'URL publique complète d'accès.

Notre code initial supposait qu'il fallait *toujours* ajouter `/file=` devant le chemin reçu.
Cependant, l'API renvoyait parfois un chemin qui contenait déjà une partie de la structure, ou inversement, nous utilisions une propriété (`path`) qui nécessitait une construction différente de celle prévue.

De plus, l'accès direct aux fichiers temporaires de Gradio nécessite l'endpoint spécifique `/file=`. Si on oublie ce préfixe ou si on le met en double, le serveur ne trouve pas le fichier et renvoie sa page 404 standard (d'où le HTML dans l'erreur).

## 3. La Solution
Nous avons mis en place une logique de parsing plus robuste :

### A. Priorité à la propriété `url`
Dans la classe `PredictResult`, nous regardons maintenant d'abord si l'objet réponse contient une clé `url`. Cette clé est fournie par Gradio spécifiquement pour l'accès web et est généralement plus fiable que le `path` brut interne.

```dart
// Extrait de PredictResult
if (v is Map && v.containsKey('url')) return v['url']; // Priorité !
if (v is Map && v.containsKey('path')) return v['path'];
```

### B. Construction Intelligente de l'URL
Dans la fonction d'affichage (`_buildImageFromSrc`), nous vérifions le format de la chaîne reçue avant de construire l'URL finale :

```dart
String fullUrl = src;
if (!src.startsWith('http')) {
   final baseUrl = "https://nachosanchezz-melanoma.hf.space";
   // Si ça commence déjà par /file=, on concatène juste
   if (src.startsWith('/file=')) {
     fullUrl = "$baseUrl$src";
   } else {
     // Sinon on ajoute le préfixe nécessaire
     fullUrl = "$baseUrl/file=$src";
   }
}
```

## Conclusion
Le problème venait d'une ambiguïté sur le format des chemins renvoyés par l'API. En inspectant le corps de la réponse d'erreur (le HTML), nous avons compris que nous frappions à la mauvaise porte (mauvaise URL). La solution a été de s'adapter dynamiquement au format renvoyé par le serveur.
