# Installation Directe — Astra AI

Ce guide explique comment installer Astra AI directement sur votre iPhone, sans passer par l'App Store.

## Trois méthodes disponibles

| Méthode | Compte requis | Expire | Difficulté |
|---------|--------------|--------|------------|
| Xcode (USB) | Apple ID gratuit | 7 jours | Facile |
| AltStore / Sideloadly | Apple ID gratuit | 7 jours | Moyenne |
| Ad Hoc (payant) | Apple Developer (99$/an) | 1 an | Moyenne |

---

## Méthode 1 — Installation directe via Xcode (recommandée)

La méthode la plus simple. L'app est installée directement sur l'iPhone connecté.

### Prérequis
- macOS avec Xcode 16+
- Un Apple ID (gratuit)
- Un iPhone connecté en USB

### Étapes

1. **Ouvrez le projet dans Xcode**
   ```bash
   open AstraAI.xcodeproj
   ```

2. **Ajoutez votre compte Apple**
   - Xcode → Settings (⌘,) → Accounts
   - Cliquez sur "+" → Apple ID
   - Connectez-vous avec votre Apple ID

3. **Sélectionnez votre équipe**
   - Cliquez sur la target "AstraAI" dans le navigateur de projet
   - Onglet "Signing & Capabilities"
   - Cochez "Automatically manage signing"
   - Sélectionnez votre équipe (Team) dans le menu déroulant

4. **Sélectionnez votre iPhone**
   - Dans la barre de destination, sélectionnez votre iPhone connecté
   - Sur l'iPhone : "Faire confiance à cet ordinateur"

5. **Compilez et installez**
   - Appuyez sur ⌘+R (Run) ou cliquez sur Play
   - L'app se compile, se signe et s'installe automatiquement

### En ligne de commande
```bash
# Récupérez votre Team ID depuis Xcode → Settings → Accounts
./scripts/install_direct.sh VOTRE_TEAM_ID
```

### Important
- Avec un compte gratuit, le profil expire après **7 jours**
- L'app devra être réinstallée après expiration
- Vous devrez aussi aller dans Réglages → Général → Profils et gestion de l'appareil → Approuver le développeur

---

## Méthode 2 — AltStore / Sideloadly (sideloading)

Cette méthode produit un fichier .ipa non signé que vous installez ensuite via AltStore ou Sideloadly.

### Étape 1 : Générer l'IPA non signé

```bash
./scripts/build_unsigned_ipa.sh
```

Le fichier `build/AstraAI-unsigned.ipa` sera créé.

### Étape 2 : Installer via AltStore

1. Installez [AltServer](https://altstore.io) sur votre Mac
2. Installez AltStore sur votre iPhone (via AltServer)
3. Connectez votre iPhone en USB
4. Ouvrez AltStore sur l'iPhone
5. Appuyez sur "+" → Sélectionnez le fichier .ipa
6. AltStore signe et installe l'app avec votre Apple ID

### Étape 2 (alternative) : Installer via Sideloadly

1. Téléchargez [Sideloadly](https://sideloadly.io) (Mac ou Windows)
2. Connectez votre iPhone en USB
3. Glissez le fichier .ipa dans Sideloadly
4. Entrez votre Apple ID
5. Cliquez sur "Start"

### Important
- L'IPA non signé ne peut pas être installé directement en tapant dessus
- AltStore/Sideloadly signe l'app avec votre Apple ID
- Le certificat expire après 7 jours (compte gratuit)
- AltStore peut rafraîchir automatiquement l'app en arrière-plan

---

## Méthode 3 — Ad Hoc (compte payant)

Pour une installation longue durée (1 an), avec un compte Apple Developer payant.

### Prérequis
- Compte Apple Developer (99$/an)
- UDID de l'iPhone enregistré dans votre compte developer

### Étapes

1. **Récupérez l'UDID de votre iPhone**
   - Connectez l'iPhone en USB
   - Ouvrez Xcode → Window → Devices and Simulators
   - Copiez l'UDID (clic droit → Copy)

2. **Ajoutez l'appareil dans le Developer Portal**
   - https://developer.apple.com/account/resources/devices
   - "Add Devices" → collez l'UDID

3. **Créez un profil de provisioning Ad Hoc**
   - https://developer.apple.com/account/resources/profiles
   - Nouveau profil → Ad Hoc → sélectionnez l'appareil

4. **Générez l'IPA signé**
   ```bash
   ./scripts/build_signed_ipa.sh VOTRE_TEAM_ID com.votrenom.astraai ad-hoc
   ```

5. **Installez l'IPA**
   - Glissez le .ipa dans Xcode → Devices and Simulators
   - Ou utilisez Apple Configurator 2

---

## Méthode 4 — OTA (Over The Air, Ad Hoc uniquement)

Pour installer sans USB, via un lien HTTPS.

### Prérequis
- Compte Apple Developer payant
- Un serveur HTTPS pour héberger les fichiers

### Étapes

1. Générez l'IPA Ad Hoc (voir Méthode 3)

2. Hébergez l'IPA sur un serveur HTTPS :
   ```
   https://votre-serveur.com/astraai/AstraAI-ad-hoc.ipa
   ```

3. Créez un fichier manifest.plist :
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>items</key>
       <array>
           <dict>
               <key>assets</key>
               <array>
                   <dict>
                       <key>kind</key>
                       <string>software-package</string>
                       <key>url</key>
                       <string>https://votre-serveur.com/astraai/AstraAI-ad-hoc.ipa</string>
                   </dict>
               </array>
               <key>metadata</key>
               <dict>
                   <key>bundle-identifier</key>
                   <string>com.votrenom.astraai</string>
                   <key>bundle-version</key>
                   <string>1.0</string>
                   <key>kind</key>
                   <string>software</string>
                   <key>title</key>
                   <string>Astra AI</string>
               </dict>
           </dict>
       </array>
   </dict>
   </plist>
   ```

4. Ouvrez ce lien sur l'iPhone :
   ```
   itms-services://?action=download-manifest&url=https://votre-serveur.com/astraai/manifest.plist
   ```

---

## Dépannage

### "Untrusted Developer"
Après installation, allez dans :
**Réglages → Général → Profils et gestion de l'appareil → Approuver le développeur**

### "Could not validate the application"
- Vérifiez que l'heure de l'iPhone est correcte (Réglages → Général → Date et heure → Automatique)
- Le certificat a peut-être expiré

### "This app cannot be installed because its integrity could not be verified"
- Re-signez l'app (le profil de 7 jours a expiré)
- En mode Développeur : Réglages → Confidentialité et sécurité → Mode développeur

### Activer le Mode Développeur (iOS 16+)
1. Réglages → Confidentialité et sécurité
2. Faites défiler jusqu'en bas → Mode développeur
3. Activez-le → Redémarrez l'iPhone

### Problème de signature
Si Xcode ne trouve pas de certificat :
1. Xcode → Settings → Accounts
2. Sélectionnez votre Apple ID → Manage Certificates
3. Cliquez sur "+" → Apple Development
4. Rechargez le projet

---

## Résumé des scripts

| Script | Usage | Résultat |
|--------|-------|----------|
| `scripts/install_direct.sh [TEAM_ID]` | Installation directe via USB | App installée sur l'iPhone |
| `scripts/build_unsigned_ipa.sh` | IPA non signé | `build/AstraAI-unsigned.ipa` |
| `scripts/build_signed_ipa.sh TEAM_ID [BUNDLE_ID] [METHOD]` | IPA signé | `build/AstraAI-development.ipa` |
