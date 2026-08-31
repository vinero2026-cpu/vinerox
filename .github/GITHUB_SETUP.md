# GitHub Actions Build Setup

This project uses GitHub Actions to automatically build and generate Flutter APK/AAB files with Target SDK 35 for Google Play compliance.

## How it works:

1. **Workflow File**: `.github/workflows/build-and-upload.yml`
   - Triggers on push to `main` or `master` branches
   - Runs on Ubuntu latest runner (has Android SDK pre-installed)
   - Builds both APK and AAB in release mode
   - Uploads artifacts to GitHub Actions

2. **Configuration**:
   - Flutter: 3.29.3 (stable)
   - Java: 11 (Temurin)
   - Target SDK: 35 (hardcoded in android/app/build.gradle.kts)
   - Compile SDK: 35 (hardcoded in android/app/build.gradle.kts)

3. **To trigger build**:
   - Push code to GitHub (main/master branch)
   - OR manually trigger via GitHub Actions > "Run workflow" > "Run workflow"

4. **To download artifacts**:
   - Go to: GitHub Actions > Latest workflow run
   - Download "vinerox-apk" or "vinerox-aab" artifact
   - Use downloaded AAB to upload to Google Play Console

## Next steps:

1. Initialize git and push to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: VINEROX app with Target SDK 35"
   git remote add origin https://github.com/YOUR_USERNAME/vinerox.git
   git branch -M main
   git push -u origin main
   ```

2. GitHub Actions will start building automatically

3. Download AAB artifact and upload to Google Play Console
