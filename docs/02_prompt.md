# Prompt Original

## Contexte
Agis en tant qu'expert en Flutter et développement mobile.

## Objectif
Je veux créer un NOUVEAU projet Flutter en me basant sur le code du projet actuel de "Trash/Garbage Detection". La nouvelle application sera un **"Visualiseur Multi-Modèle de Détection de Mélanome"**.

Tu dois prendre en charge la création complète du fichier en incluant toutes les logiques de configuration, permissions et injection de scripts.

---

## Règle Critique : Transformation des URLs

Les "Hugging Face Spaces" ont une URL publique et une URL directe. Tu dois implémenter une fonction qui transforme automatiquement toute URL fournie par moi ou par l'utilisateur selon cette logique :

- **Entrée (Originale) :** `https://huggingface.co/spaces/UTILISATEUR/REPO`
- **Sortie (Directe) :** `https://UTILISATEUR-REPO.hf.space`
- **Logique :** Remplace le slash `/` entre l'utilisateur et le nom du repo par un tiret `-`, et change le domaine en `.hf.space`.

---

## Fonctionnalités Requises

### 1. Menu de Sélection de Modèles
Implémente une interface ergonomique pour basculer rapidement entre différents modèles.

### 2. Liste Initiale de Modèles
L'application doit démarrer avec cette liste préchargée. Applique la règle de transformation ci-dessus à ces URL originales avant de les charger :

- `https://huggingface.co/spaces/sapnashettyy/melanoma-detector`
- `https://huggingface.co/spaces/ish028792/melanoma`
- `https://huggingface.co/spaces/dehannoor3199/melanoma-detection-system`
- `https://huggingface.co/spaces/sapnashettyy/melanoma-detector2`
- `https://huggingface.co/spaces/Nachosanchezz/Melanoma`

### 3. Ajout Dynamique de Modèle
Ajoute un moyen pour l'utilisateur d'ajouter une nouvelle URL originale Hugging Face. Le code doit détecter le format et le transformer automatiquement.

### 4. Blocage de Navigation
Modifie le `NavigationDelegate` pour autoriser uniquement la navigation au sein du domaine `.hf.space` du modèle actif et bloquer tout le reste pour que l'utilisateur ne sorte pas de l'outil.

### 5. Amélioration Visuelle
Le but est que l'application ressemble le plus possible à une application native.
- Implémente une logique d'injection JavaScript/CSS.
- **Mission :** Propose et intègre un code CSS intelligent pour masquer les éléments de l'interface web de Hugging Face qui ne sont pas nécessaires dans une app mobile (comme les headers, footers, ou barres de navigation web), afin d'offrir une expérience utilisateur propre et immersive.

### 6. Gestion des Permissions
Le code doit inclure toute la logique nécessaire pour demander l'accès à la **Caméra** et à la **Galerie**, car ces modèles nécessitent l'upload d'images. Réplique la logique robuste du projet base pour la compatibilité Android.

---

## Livrable
Génère le code complet et fonctionnel dans un projet nouveau.
