# 🚀 VINEROX Google Play Compliance - Build & Deploy Guide

## Status: ✅ READY TO BUILD

Your VINEROX Flutter app is now configured for Google Play 2026 compliance with **Target SDK 35**.

### What's Been Done:

✅ **Android Configuration Fixed:**
- `android/app/build.gradle.kts`: `compileSdk = 35`, `targetSdk = 35`
- `android/app/build.gradle.kts`: `applicationId = "app.vinero.vinerox_mobile"` (correct package name)
- `pubspec.yaml`: Version bumped to `1.0.0+2`
- All 62 Flutter dependencies resolved and locked

✅ **GitHub Actions Workflow Created:**
- `.github/workflows/build-and-upload.yml` - Automatically builds APK/AAB with Target SDK 35
- Triggers on push to main branch
- Builds on Ubuntu runner (has Android SDK pre-installed)

---

## 📋 Quick Start (5 Steps)

### Step 1: Install Git for Windows
If you don't have Git installed:
1. Go to: https://git-scm.com/download/win
2. Download and install Git for Windows
3. Use default settings
4. Restart any terminal windows after installation

### Step 2: Create GitHub Account & Repository
1. Go to: https://github.com/signup
2. Create a GitHub account (if you don't have one)
3. Verify your email
4. Create a new repository:
   - Go to: https://github.com/new
   - Repository name: `vinerox` (or any name you prefer)
   - Description: "VINEROX - Stock Arena mobile app with Target SDK 35"
   - Privacy: **Public** (required for free GitHub Actions)
   - Click "Create repository"

### Step 3: Generate GitHub Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set these options:
   - **Token name:** `VINEROX_BUILD`
   - **Expiration:** 90 days
   - **Scopes:** Check `repo` (full control of private repositories)
4. Click "Generate token"
5. **Copy the token immediately** (you'll need it in 30 seconds)

### Step 4: Run GitHub Setup Script

**On Windows:**
```powershell
# Navigate to project directory
cd E:\VINEROX\mobile_app

# Run the setup script
.\SETUP_GITHUB.bat
```

**On macOS/Linux:**
```bash
cd /path/to/mobile_app
chmod +x SETUP_GITHUB.sh
./SETUP_GITHUB.sh
```

**What the script will ask:**
```
Git user name? → press Enter (uses "VINEROX Build")
Git email? → press Enter (uses "build@vinerox.app")
GitHub repository URL? → https://github.com/YOUR_USERNAME/vinerox.git
Do you want to push now? → y (yes)
GitHub username? → YOUR_GITHUB_USERNAME
GitHub password? → PASTE_YOUR_PERSONAL_ACCESS_TOKEN (not your password!)
```

### Step 5: Monitor Build
1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/vinerox`
2. Click "Actions" tab
3. Wait for workflow to complete (~10-15 minutes)
4. Download artifacts: APK and AAB files

---

## 📦 Downloading Build Artifacts

After GitHub Actions completes:

1. Go to: `https://github.com/YOUR_USERNAME/vinerox/actions`
2. Click the latest workflow run (green checkmark ✅)
3. Scroll down to "Artifacts"
4. Download:
   - **vinerox-aab** (for Google Play Console) ← **Use this one**
   - **vinerox-apk** (direct APK for sideloading)

---

## 🎯 Upload to Google Play Console

### Via Browser:
1. Go to: https://play.google.com/console
2. Click "Stock Arena: Vinerox" app
3. Go to: "Release" → "Production" (or "Testing")
4. Click "Create new release"
5. Upload the **app-release.aab** file (from downloaded artifact)
6. Set version notes: "Version 1.0.0 - Google Play 2026 compliance (Target SDK 35)"
7. Review and submit

### Expected Result:
✅ **PASS** - Google Play should accept the build (Target SDK 35 ✓)

---

## 🔧 Manual Alternative (If GitHub Push Fails)

If you can't use GitHub Actions, use this workaround:

### Option A: Download Android Studio
1. Download: https://developer.android.com/studio
2. Install (2GB, takes ~30 min)
3. Open VINEROX project in Android Studio
4. Click "Build" → "Build Bundle(s) / APK(s)" → "Build AAB"
5. Found in: `mobile_app/build/app/outputs/bundle/release/app-release.aab`

### Option B: Use Docker
```bash
# Pull Flutter Docker image with Android SDK
docker pull instrumentisto/flutter:3.29.3

# Build AAB
docker run -v E:\VINEROX\mobile_app:/app instrumentisto/flutter:3.29.3 \
  flutter build appbundle --release --output-dir=build

# AAB will be in: mobile_app/build/app-release.aab
```

---

## ⏰ Timeline Reminder

- **TODAY is the deadline: August 31, 2026**
- **Target SDK 35 requirement: CRITICAL** ✓ Already configured
- **Google Play acceptance time: Usually ~2-24 hours**

---

## 📞 Troubleshooting

### "Git is not recognized"
- Install Git for Windows: https://git-scm.com/download/win
- Restart PowerShell/Command Prompt after installation

### "Authentication failed"
- Make sure you're using your Personal Access Token (not your GitHub password)
- Token must have `repo` scope enabled
- Token expires - if stuck, generate a new one

### "Workflow failed" (GitHub Actions)
- Check the "Actions" tab in your GitHub repo
- Click the failed workflow for detailed error logs
- Common issues:
  - Java not installed (workflow includes Java 11)
  - Android SDK download timeout (rare, workflow retries automatically)

### "Google Play still rejects the AAB"
- Verify in `build.gradle.kts`: `targetSdk = 35` ✓
- Verify in `build.gradle.kts`: `compileSdk = 35` ✓
- Check Google Play error message for specific issues
- Contact Google Play Support if still rejected

---

## ✨ After Successful Submission

1. Google Play reviews your app (2-24 hours typically)
2. Check email for approval notification
3. If approved: Click "Release to Production" in Play Console
4. App becomes available to users in ~2-4 hours
5. **Deadline met:** ✅ Compliance achieved before August 31, 2026

---

## Files Created for You

```
mobile_app/
├── .github/workflows/build-and-upload.yml      ← GitHub Actions workflow
├── .github/GITHUB_SETUP.md                     ← This documentation
├── SETUP_GITHUB.bat                            ← Windows setup script
├── SETUP_GITHUB.sh                             ← macOS/Linux setup script
├── android/app/build.gradle.kts                ← MODIFIED: SDK 35 ✓
├── pubspec.yaml                                ← MODIFIED: v1.0.0+2 ✓
└── lib/main.dart                               ← Unchanged
```

---

## 🎉 Summary

Your app is ready. The only steps you need:
1. Install Git (if not already installed)
2. Create GitHub account/repo
3. Generate personal access token
4. Run `SETUP_GITHUB.bat` (or `.sh` on Mac/Linux)
5. Wait for GitHub Actions to build
6. Download AAB and upload to Google Play Console
7. **DEADLINE MET** ✅

**Good luck! 🚀**
