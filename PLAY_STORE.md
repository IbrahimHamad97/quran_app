# Google Play publishing checklist

Personal / non-commercial release. Verification status (local):

- `flutter analyze` — clean
- `flutter test` — all passed
- Assets present: `quran.sqlite` (~1.7 MB), `tafsir.sqlite` (~43 MB), Arabic font
- Data: 114 surahs, 6236 ayahs, 604 pages, 6 tafsir editions

Attribution details for store / legal text: [REFERENCES.md](REFERENCES.md)

---

## 1. Before you generate the release file

### A. Change the application ID (required)

Play Store rejects `com.example.*`.

In [`android/app/build.gradle`](android/app/build.gradle) set **both**:

```gradle
namespace = "com.yourname.qurantafsir"
applicationId = "com.yourname.qurantafsir"
```

Use a unique ID you own (often reverse-domain). This cannot be changed later for the same listing.

Also update Kotlin package folders under `android/app/src/main/kotlin/` if the package path still says `com/example/quran_app` (move `MainActivity.kt` to match).

### B. Create a release keystore (one-time)

In a terminal (pick your own passwords and keep them safe):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store `upload-keystore.jks` **outside** git (or only locally). Never commit the keystore or passwords.

Create `android/key.properties` (already gitignored pattern recommended):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\path\\to\\upload-keystore.jks
```

Wire signing in `android/app/build.gradle` (release must **not** use `signingConfigs.debug`).

Example pattern:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### C. Version

In [`pubspec.yaml`](pubspec.yaml):

```yaml
version: 1.0.0+1
```

- `1.0.0` = versionName (what users see)
- `+1` = versionCode (integer; must increase every Play upload)

### D. Store assets you need to prepare

| Asset | Notes |
|-------|--------|
| App icon | 512×512 PNG (Play Console) |
| Feature graphic | 1024×500 |
| Screenshots | At least 2 phone screenshots |
| Short description | ≤80 characters |
| Full description | Features + that content is offline |
| Privacy policy URL | Required by Play for most apps — see section 3 |

---

## 2. What to generate

Build an **Android App Bundle** (not a fat APK):

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Output file:

```text
build/app/outputs/bundle/release/app-release.aab
```

Upload that `.aab` in Play Console → your app → Production (or Internal testing first).

Optional smoke test on a device:

```bash
flutter install --release
```

---

## 3. Privacy policy (short text you can host)

Host this on GitHub Pages, Notion public page, Google Doc “anyone with link”, etc., then paste the URL in Play Console.

Suggested text:

> **Privacy Policy — Quran & Tafsir**  
> This app works offline. It does not require an account and does not collect personal data, analytics, or advertising IDs.  
> Bookmarks, notes, reading position, and settings are stored only on your device.  
> No data is sent to our servers (there are none).  
> Contact: [your email]

---

## 4. Play Console steps (you already have a developer account)

1. [Google Play Console](https://play.google.com/console) → **Create app**
2. Fill app name: **Quran & Tafsir** (or your choice)
3. Declarations: free app, no ads (if true), target audience, content rating questionnaire
4. **Store listing**: descriptions, icon, feature graphic, screenshots
5. **Privacy policy** URL
6. **App content** / Data safety: declare that you don’t collect user data (on-device only)
7. **Release** → Internal testing (recommended first) → upload `app-release.aab`
8. After internal test OK → promote to **Production** → submit for review

---

## 5. Store listing copy (draft)

**Short description**

> Offline Quran reader with Arabic text, tafsir, bookmarks, and resume.

**Full description (draft)**

> Quran & Tafsir is a personal offline app for reading the Arabic Quran with classic tafsir commentaries.
>
> Features:
> • Full Arabic Quran with page and juz indicators  
> • Continuous reading across surahs  
> • Tafsir: Ibn Kathir, al-Jalalayn, and Al-Mukhtasar (Arabic & English)  
> • Search, juz/page browse, bookmarks and notes  
> • Dark / light / system theme  
> • No account and no internet required after install  
>
> Built for personal use. Quran text and tafsir are provided from public datasets; see open-source notices / app documentation for attribution.

In **Open-source licenses** / “About this app” you can summarize links from [REFERENCES.md](REFERENCES.md).

---

## 6. Common reject reasons to avoid

- Leaving `applicationId` as `com.example.quran_app`
- Signing with the debug key
- Missing privacy policy URL
- Misleading claims (e.g. “official” Mushaf)
- Broken install on a real phone — always test the release build once
