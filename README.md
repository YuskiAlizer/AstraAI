# Astra AI — Agent IA Personnel pour iOS

Astra AI est une application iOS native construite avec SwiftUI, conçue comme un véritable agent IA personnel avec une architecture modulaire de skills/tools. L'agent reçoit une demande, détermine les compétences nécessaires, les exécute automatiquement, raisonne sur les résultats, et produit une réponse finale.

## Architecture

```
AstraAI/
├── App/
│   ├── AstraAIApp.swift          # Point d'entrée de l'application
│   ├── AppEnvironment.swift      # Environnement global (DI container)
│   └── FileManagerExtension.swift
├── Core/
│   ├── Agent/
│   │   ├── AgentCore.swift       # Boucle d'agent (cerveau)
│   │   ├── AgentContext.swift     # Contexte d'exécution des skills
│   │   ├── AgentEvent.swift       # Événements pour l'UI
│   │   ├── AgentMessage.swift     # Modèles de messages
│   │   └── ToolCall.swift         # Appels d'outils et confirmations
│   ├── Providers/
│   │   ├── AIProvider.swift       # Protocole provider + modèles
│   │   ├── AIProviderRegistry.swift  # Registre + implémentations
│   │   ├── AIProviderSettings.swift  # Configuration persistante
│   │   └── ProviderImplementations.swift
│   ├── Skills/
│   │   ├── AgentSkill.swift       # Protocole skill + permissions
│   │   └── SkillRegistry.swift    # Registre + settings store
│   ├── Storage/
│   │   ├── AppLogger.swift        # Système de logs
│   │   ├── ConversationStore.swift
│   │   ├── MemoryStore.swift      # Mémoire persistante
│   │   └── SecureKeyStore.swift   # Stockage Keychain
│   └── Networking/
│       ├── HTTPClient.swift      # Client HTTP avec retry
│       └── JSONValue.swift       # Type JSON dynamique
├── Skills/                       # Implémentations des skills
│   ├── WebSearch/                # Recherche web (Brave/Bing)
│   ├── News/                     # Actualités (NewsAPI/GNews)
│   ├── WebBrowser/               # Récupération de pages web
│   ├── Voice/                    # Saisie vocale + synthèse vocale
│   ├── Vision/                   # OCR + détection d'objets
│   ├── Files/                    # Lecture/création de fichiers
│   ├── Memory/                   # Gestion de la mémoire
│   ├── Calendar/                 # Calendrier + Rappels (EventKit)
│   ├── Weather/                  # Météo (Open-Meteo, sans clé)
│   ├── API/                      # Appels API génériques
│   └── Code/                     # Génération/analyse de code
├── UI/                           # Interface SwiftUI
│   ├── RootView.swift            # Navigation par onglets
│   ├── Chat/                     # Interface de chat
│   ├── Voice/                    # Interface vocale
│   ├── Skills/                   # Gestion des skills
│   ├── Memory/                   # Gestion de la mémoire
│   ├── History/                  # Historique des conversations
│   └── Settings/                 # Paramètres + logs
└── Resources/
    ├── Info.plist                # Permissions iOS
    └── Assets.xcassets           # Icônes et couleurs
```

## Boucle d'Agent (Agent Loop)

```
USER INPUT → CONTEXT → MODEL → TOOL SELECTION → SKILL EXECUTION
→ RESULT → MODEL → FINAL RESPONSE
```

- L'agent envoie la demande au modèle IA avec les définitions d'outils disponibles
- Le modèle choisit les outils nécessaires et fournit les paramètres
- L'agent exécute les skills correspondants
- Les résultats sont renvoyés au modèle pour raisonnement
- La boucle continue jusqu'à la réponse finale ou la limite d'itérations (6 par défaut)
- Les actions sensibles demandent confirmation à l'utilisateur

## Skills implémentés

| Skill | Description | Permissions requises | Clé API requise |
|-------|-------------|---------------------|-----------------|
| WebSearch | Recherche Internet (Brave/Bing) | Réseau | Oui (Brave ou Bing) |
| News | Actualités (NewsAPI/GNews) | Réseau | Oui (NewsAPI ou GNews) |
| WebBrowser | Récupération de pages web | Réseau | Non |
| VoiceInput | Reconnaissance vocale (Speech) | Microphone, Reconnaissance vocale | Non |
| VoiceOutput | Synthèse vocale (AVSpeech) | Aucune | Non |
| Vision | OCR + détection d'objets (Vision) | Caméra | Non |
| Files | Lecture/création de fichiers | Accès fichiers | Non |
| Memory | Mémoire persistante | Aucune | Non |
| Calendar | Calendrier (EventKit) | Calendrier | Non |
| Reminders | Rappels (EventKit) | Rappels | Non |
| Weather | Météo (Open-Meteo) | Réseau, Localisation (optionnel) | Non |
| API | Appels API génériques | Réseau | Variable |
| Code | Génération/analyse de code | Réseau | Backend pour exécution |

## Configuration des clés API

### 1. Clé API du fournisseur IA (obligatoire)

Ouvrez l'application → Réglages → Fournisseur IA → Sélectionnez le fournisseur → Entrez votre clé API.

Fournisseurs supportés :
- **OpenAI** : Clé API sur https://platform.openai.com/api-keys
- **Anthropic** : Clé API sur https://console.anthropic.com/ (via endpoint compatible OpenAI — un adaptateur natif est prévu)
- **Google Gemini** : Clé API sur https://aistudio.google.com/apikey (via endpoint compatible OpenAI — un adaptateur natif est prévu)
- **NVIDIA** : Clé API sur https://build.nvidia.com/
- **Local (Ollama)** : Aucune clé requise. Démarrez Ollama sur votre machine locale.

### 2. Clés API pour les skills de recherche

Ouvrez l'application → Réglages → Clés API → Gérer les clés API.

Identifiants à utiliser :
- `brave_search` : Clé API Brave Search (https://api.search.brave.com/)
- `bing_search` : Clé API Bing Search (Azure Cognitive Services)
- `newsapi` : Clé API NewsAPI (https://newsapi.org/)
- `gnews` : Clé API GNews (https://gnews.io/)
- `code_backend_url` : URL de votre backend sandboxé pour l'exécution de code

Aucune clé API n'est jamais stockée en clair. Toutes les clés sont chiffrées via le Keychain iOS.

### 3. Endpoint personnalisé

Si vous utilisez un proxy ou un serveur compatible :
Réglages → Endpoint → Saisissez l'URL.

## Compilation avec Xcode

### Prérequis
- macOS 14.0 ou supérieur
- Xcode 16.0 ou supérieur
- iOS 17.0+ comme cible de déploiement

### Étapes

1. Ouvrez le projet dans Xcode :
   ```bash
   open AstraAI.xcodeproj
   ```

2. Sélectionnez votre équipe de développement :
   - Cliquez sur la target "AstraAI" dans le navigateur de projet
   - Onglet "Signing & Capabilities"
   - Cochez "Automatically manage signing"
   - Sélectionnez votre équipe (Team)

3. Sélectionnez un simulateur ou votre iPhone connecté

4. Compilez et exécutez :
   - `Cmd + R` ou bouton Play

### Compilation en .ipa

#### Méthode 1 : Archive (recommandée)

1. Sélectionnez le device "Any iOS Device (arm64)" dans Xcode
2. Menu : Product → Archive (`Cmd + Shift + B` puis Archive)
3. Une fois l'archive terminée, ouvrez l'Organizer (`Cmd + Shift + O`)
4. Sélectionnez l'archive → "Distribute App"
5. Choisissez "Development" ou "Ad Hoc" ou "App Store Connect"
6. Suivez les étapes pour générer le .ipa

#### Méthode 2 : Ligne de commande

```bash
# Nettoyer
xcodebuild clean -project AstraAI.xcodeproj -scheme AstraAI

# Compiler l'archive
xcodebuild archive \
  -project AstraAI.xcodeproj \
  -scheme AstraAI \
  -archivePath build/AstraAI.xcarchive \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID

# Exporter en .ipa
xcodebuild -exportArchive \
  -archivePath build/AstraAI.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/ipa
```

Créez un fichier `ExportOptions.plist` :
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

## Installation directe (sans App Store)

Astra AI peut être installé directement sur votre iPhone de trois manières :

1. **Xcode (USB)** — le plus simple, via `./scripts/install_direct.sh`
2. **AltStore / Sideloadly** — via un .ipa non signé généré par `./scripts/build_unsigned_ipa.sh`
3. **Ad Hoc (compte payant)** — via `./scripts/build_signed_ipa.sh TEAM_ID BUNDLE_ID ad-hoc`

Voir le guide complet : [DirectInstall/README_DIRECT_INSTALL.md](DirectInstall/README_DIRECT_INSTALL.md)

Avec un compte Apple ID gratuit, l'app expire après 7 jours et doit être réinstallée. Avec un compte Apple Developer payant (99$/an), l'app est valide 1 an.

## Sécurité

- Aucune clé API n'est codée en dur dans l'application
- Toutes les clés sont stockées dans le Keychain iOS (chiffrées)
- L'application respecte strictement le sandbox iOS
- Chaque permission est demandée individuellement avec une explication
- L'agent ne peut pas accéder à des données sans autorisation explicite
- Les actions sensibles demandent confirmation à l'utilisateur
- Aucune donnée n'est envoyée à un serveur tiers sans le consentement de l'utilisateur
- Les logs ne contiennent jamais de clés API ou de données sensibles

## Tests

Le projet inclut des tests unitaires :
- `AgentCoreTests` : Tests de l'agent core, de la limite d'itérations, et de l'annulation
- `SkillRegistryTests` : Tests du registre de skills, de l'activation/désactivation
- `MemoryStoreTests` : Tests CRUD de la mémoire, recherche, persistance
- `JSONValueAndConversationTests` : Tests des types JSON, du store de conversations

Pour exécuter les tests : `Cmd + U` dans Xcode

## Ajout de nouveaux skills

1. Créez un nouveau fichier Swift dans `Skills/VotreSkill/`
2. Conformez-vous au protocole `AgentSkill`
3. Implémentez `execute(input:context:)`
4. Enregistrez le skill dans `AppEnvironment.registerSkills()`

```swift
final class MyCustomSkill: AgentSkill {
    let id = "my_custom_skill"
    let name = "Mon Skill"
    let description = "Description de mon skill"
    let category: SkillCategory = .general
    let requiredPermissions: [SkillPermission] = []

    var inputSchema: JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "param": .object(["type": .string("string")])
            ])
        ])
    }

    var outputSchema: JSONValue {
        .object(["type": .string("object")])
    }

    func execute(input: JSONValue, context: SkillExecutionContext) async throws -> SkillResult {
        // Votre logique ici
        return SkillResult(output: .object(["result": .string("OK")]))
    }
}
```

Puis dans `AppEnvironment.swift` :
```swift
skillRegistry.register(MyCustomSkill())
```

## Limitations techniques connues

- **WebBrowser** : Ne peut pas exécuter JavaScript ou contourner les paywalls
- **Vision** : La détection d'objets dépend des modèles CoreML disponibles sur l'appareil
- **Code** : L'exécution de code nécessite un backend sandboxé séparé (par sécurité)
- **WebSearch/News** : Nécessitent une clé API configurée — ne fonctionnent pas sans
- **Speech Recognition** : Nécessite une connexion Internet pour la reconnaissance à la demande
- **EventKit** : Les permissions doivent être accordées dans les réglages iOS si refusées

## Technologies

- **Langage** : Swift 5
- **UI** : SwiftUI
- **Concurrency** : Swift Concurrency (async/await, actors)
- **Plateforme** : iOS 17+
- **Frameworks** : Speech, AVFoundation, Vision, EventKit, PDFKit, CoreLocation, Security (Keychain)
- **Architecture** : MVVM + Agent Loop pattern
