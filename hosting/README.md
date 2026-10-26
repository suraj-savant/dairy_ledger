# Hosting (account links and QR codes)

Static site served by Firebase Hosting from `hosting/public`:

* `index.html` — shown when someone opens `https://<domain>/a/<accountId>` and the app did not
  take the link (app not installed). It sends them to the Play Store.
* `.well-known/assetlinks.json` — lets Android open the app directly for these links
  (Android App Links verification).

Each Firebase project serves its own domain:

| Flavor | Project | Domain |
|---|---|---|
| dev | `dev-dairyledger` | `dev-dairyledger.web.app` |
| prod | `dairyledgerapp` | `dairyledgerapp.web.app` |

## Before deploying to prod

Replace both placeholders in `.well-known/assetlinks.json` with the SHA-256 fingerprints of the
**Play App Signing key** (Play Console > Setup > App signing) and of the **upload key**
(`keytool -list -v -keystore <upload-keystore.jks> -alias upload`). The dev entry already holds the
debug key's SHA-256.

## Deploy

```bash
firebase login:use <account-of-that-project>
firebase deploy --only hosting --project dev-dairyledger     # or dairyledgerapp
firebase deploy --only firestore --project dev-dairyledger   # rules + indexes
```

Check a link after deploying: `https://<domain>/.well-known/assetlinks.json` must return the JSON,
and `adb shell pm get-app-links com.dairyledger.app.dev` should show the domain as `verified`.
