---
description: Release vorbereiten und veröffentlichen — $ARGUMENTS
argument-hint: <Version, z. B. v0.10.1-beta>
---

Release **$ARGUMENTS** vorbereiten. Halte dich an
`docs/07-release-playbook.md`.

Vor dem Bauen prüfen:

1. Bin ich auf `main` und ist `main` aktuell? Gibt es Branches, die noch
   vor `main` liegen? Wenn ja: **stopp**, die gehören erst gemerged.
2. Version in `app/pubspec.yaml` **und** `AppConfig.appVersion` in
   `app/lib/core/config.dart` auf die Zielversion gesetzt? `versionCode`
   (die Zahl nach `+`) gegenüber dem letzten Release erhöht?
3. `flutter analyze`, `flutter test`, `flutter build web --release` grün?
4. Letzter CI-Lauf auf `main` grün (`gh run list --limit 3`)?

Dann:

- Release-Notiz auf **Deutsch**, für Nutzer verständlich, keine
  Commit-Hashes: was ist neu, was wurde behoben, was ist bekannt offen.
- Release über `gh workflow run release.yml` mit dem Input `version`
  starten — **frag mich vorher**. Ein Tag-Push scheitert mit 403
  (Branch-Scope-Token), also nicht versuchen.
- Lauf beobachten (`gh run view`), bis APK und AAB veröffentlicht sind.

Wenn die Signatur-Secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`) fehlen,
baut die CI mit Debug-Signatur — das würde Updates beim Nutzer brechen.
**In dem Fall abbrechen und mich informieren.**
