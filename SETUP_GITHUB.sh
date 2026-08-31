#!/bin/bash
# ============================================================================
# VINEROX GitHub Actions Setup Script (macOS/Linux)
# ============================================================================
# This script initializes git and pushes code to GitHub for CI/CD building
# Requirements: Git, GitHub account, personal access token
# ============================================================================

set -e

echo ""
echo "===== VINEROX GitHub Actions Setup ====="
echo ""
echo "This script will:"
echo "1. Initialize a Git repository"
echo "2. Configure git with your credentials"
echo "3. Push to GitHub (requires token)"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "ERROR: Git is not installed"
    echo "Please install Git from: https://git-scm.com/download/linux"
    exit 1
fi

echo "Git found:"
git --version
echo ""

# Configure git
read -p "Enter Git user name (or press Enter for 'VINEROX Build'): " GIT_NAME
GIT_NAME=${GIT_NAME:-"VINEROX Build"}

read -p "Enter Git email (or press Enter for 'build@vinerox.app'): " GIT_EMAIL
GIT_EMAIL=${GIT_EMAIL:-"build@vinerox.app"}

echo "Configuring Git with name: $GIT_NAME"
echo "Configuring Git with email: $GIT_EMAIL"
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Initialize repository
echo ""
echo "Initializing Git repository..."
git init
git add -A
git commit -m "VINEROX v1.0.0+2 - Target SDK 35 for Google Play 2026 compliance"
git branch -M main

echo ""
echo "===== Git Initialization Complete ====="
echo ""
git log --oneline -1
echo ""

# GitHub remote setup
echo ""
read -p "Enter your GitHub repository URL (e.g., https://github.com/YOUR_USERNAME/vinerox.git): " GITHUB_URL

if [ ! -z "$GITHUB_URL" ]; then
    echo "Adding remote origin: $GITHUB_URL"
    git remote add origin "$GITHUB_URL"
    echo ""
    echo "To push to GitHub, run:"
    echo "  git push -u origin main"
    echo ""
    echo "IMPORTANT: You will be prompted for GitHub credentials."
    echo "Use your personal access token (not password) if 2FA is enabled."
    echo ""
    read -p "Do you want to push now? (y/n): " DO_PUSH
    if [[ "$DO_PUSH" =~ ^[Yy]$ ]]; then
        echo "Pushing to GitHub..."
        if git push -u origin main; then
            echo ""
            echo "✅ Push successful!"
            echo ""
            echo "GitHub Actions will now automatically build your app."
            echo "Monitor progress at: https://github.com/YOUR_USERNAME/vinerox/actions"
        else
            echo ""
            echo "❌ Push failed. Please check your credentials and repository URL."
        fi
    fi
else
    echo "No repository URL provided. Skipping remote configuration."
    echo ""
    echo "To add GitHub remote later, run:"
    echo "  git remote add origin https://github.com/YOUR_USERNAME/vinerox.git"
    echo "  git push -u origin main"
fi

echo ""
echo "===== Setup Complete ====="
echo ""
