#!/data/data/com.termux/files/usr/bin/bash

# Enhanced self-contained wireless debugging script using termux-adb
# Usage: 
#   Default (auto calculate port):  ./script.sh
#   Fixed port:                    ./script.sh 36239 fixed

# Check parameters
DEBUG_PORT=${1:-"auto"}  # Default to "auto" if not provided
PORT_MODE=${2:-"offset"} # Default to "offset" mode if not specified

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Android Wireless Debug Setup ===${NC}"
echo -e "${YELLOW}Setting up environment...${NC}"

# Update package repositories and install essential packages
echo -e "${CYAN}Updating package repositories...${NC}"
pkg update -y || { echo -e "${RED}Failed to update packages. Please check your internet connection.${NC}"; exit 1; }

# Install basic tools
echo -e "${CYAN}Installing essential tools...${NC}"
pkg install -y python which curl || { echo -e "${RED}Failed to install essential packages.${NC}"; exit 1; }

# Install termux-adb
echo -e "${CYAN}Installing termux-adb...${NC}"
curl -s https://raw.githubusercontent.com/nohajc/termux-adb/master/install.sh | bash || { echo -e "${RED}Failed to install termux-adb.${NC}"; exit 1; }

# Check if termux-adb was successfully installed
if ! which termux-adb >/dev/null; then
    echo -e "${RED}Error: termux-adb installation failed. Please try installing it manually.${NC}"
    echo -e "${YELLOW}Command: curl -s https://raw.githubusercontent.com/nohajc/termux-adb/master/install.sh | bash${NC}"
    exit 1
fi
echo -e "${GREEN}termux-adb successfully installed!${NC}"

# Install required Python packages
echo -e "${CYAN}Installing required Python packages...${NC}"
pip install qrcode colorama zeroconf || { echo -e "${RED}Failed to install Python dependencies.${NC}"; exit 1; }

# Create and run the Python script
echo -e "${CYAN}Launching wireless debugging tool...${NC}"

if [ "$PORT_MODE" = "fixed" ]; then
    echo -e "${YELLOW}Will use fixed debug port: ${DEBUG_PORT}${NC}"
else
    if [ "$DEBUG_PORT" = "auto" ]; then
        echo -e "${YELLOW}Will automatically calculate debug port (pairing port - 1)${NC}"
    else
        echo -e "${YELLOW}Will use port offset: ${DEBUG_PORT}${NC}"
    fi
fi

python - "$DEBUG_PORT" "$PORT_MODE" << 'EOF'
#!/data/data/com.termux/files/usr/bin/python
import os
import subprocess
import time
from random import randint
import sys

# Get parameters from command line
PORT_PARAM = "auto"
PORT_MODE = "offset"

if len(sys.argv) > 1:
    PORT_PARAM = sys.argv[1]  # Could be "auto", a number for offset, or a fixed port
    
if len(sys.argv) > 2:
    PORT_MODE = sys.argv[2]   # "offset" or "fixed"

# Convert port parameter to int if it's a number
if PORT_PARAM != "auto" and PORT_PARAM.isdigit():
    PORT_PARAM = int(PORT_PARAM)
else:
    # Default offset if auto mode
    if PORT_PARAM == "auto":
        PORT_PARAM = 1

# Check if termux-adb exists using a simple command
try:
    check_cmd = ["which", "termux-adb"]
    process = subprocess.run(check_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if process.returncode != 0:
        print("\033[0;31mError: termux-adb not found. Please ensure it's installed and in your PATH.\033[0m")
        sys.exit(1)
except Exception as e:
    print(f"\033[0;31mError checking for termux-adb: {e}\033[0m")
    sys.exit(1)

# Import required packages
try:
    import qrcode
    from colorama import Fore, init as colorama_init
    from zeroconf import Zeroconf, ServiceBrowser, ServiceListener, ServiceInfo, IPVersion
except ImportError as e:
    print(f"\033[0;31mError importing required modules: {e}\033[0m")
    print("\033[0;33mPlease run: pip install qrcode colorama zeroconf\033[0m")
    sys.exit(1)

# Initialize colorama
colorama_init()

# Constants
TYPE = "_adb-tls-pairing._tcp.local."
NAME = "debug"
PASSWORD = randint(100000, 999999)
FORMAT_QR = f"WIFI:T:ADB;S:{NAME};P:{PASSWORD};;"

# Create and display QR code
qr = qrcode.QRCode()
qr.add_data(FORMAT_QR)
qr.make(fit=True)

print(f"{Fore.CYAN}=== Termux-ADB Wireless Debug ===={Fore.RESET}")
print(f"{Fore.YELLOW}Pairing code: {PASSWORD}{Fore.RESET}")

# Print QR code
qr.print_ascii(invert=True)

print(f"{Fore.YELLOW}Scan QR code with your device to pair{Fore.RESET}")
print(f"{Fore.CYAN}[Settings]{Fore.WHITE}->{Fore.CYAN}[Developer options]{Fore.WHITE}->{Fore.CYAN}[Wireless debugging]{Fore.WHITE}->{Fore.CYAN}[Pair device with QR code]{Fore.RESET}")

# Setup zeroconf for service discovery
class ADBListener(ServiceListener):
    def remove_service(self, zc, type_, name):
        pass
        
    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name)
        if not info:
            return
            
        print(f"{Fore.GREEN}Found device! Attempting to pair...{Fore.RESET}")
        self.pair(info)
        
    def pair(self, info):
        try:
            ip_address = info.ip_addresses_by_version(IPVersion.All)[0].exploded
            port = info.port
            
            print(f"{Fore.CYAN}Pairing with {ip_address}:{port}{Fore.RESET}")
            
            # Using termux-adb as specified
            cmd = f"termux-adb pair {ip_address}:{port} {PASSWORD}"
            process = subprocess.run(cmd.split(), capture_output=True, text=True)
            
            if "Successfully paired" in process.stdout:
                print(f"{Fore.GREEN}Successfully paired with {ip_address}:{port}{Fore.RESET}")
                
                # Determine debug port based on mode
                if PORT_MODE == "fixed":
                    # Use the exact port specified
                    debug_port = PORT_PARAM
                    print(f"{Fore.YELLOW}Using fixed debug port: {debug_port}{Fore.RESET}")
                else:
                    # Calculate debug port based on offset
                    debug_port = port - PORT_PARAM
                    print(f"{Fore.YELLOW}Using calculated debug port: {debug_port} (pairing port - {PORT_PARAM}){Fore.RESET}")
                
                # Try to connect automatically with termux-adb
                connect_cmd = f"termux-adb connect {ip_address}:{debug_port}"
                connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                if "connected" in connect_process.stdout.lower():
                    print(f"{Fore.GREEN}Successfully connected to {ip_address}:{debug_port}{Fore.RESET}")
                    print(f"{Fore.CYAN}You can now use termux-adb commands with this device{Fore.RESET}")
                    print(f"{Fore.YELLOW}Example commands:{Fore.RESET}")
                    print(f"{Fore.CYAN}  termux-adb devices{Fore.RESET}")
                    print(f"{Fore.CYAN}  termux-adb shell{Fore.RESET}")
                    print(f"{Fore.CYAN}  termux-adb shell pm list packages{Fore.RESET}")
                else:
                    print(f"{Fore.YELLOW}Connection response: {connect_process.stdout}{Fore.RESET}")
                    if connect_process.stderr:
                        print(f"{Fore.RED}Error: {connect_process.stderr}{Fore.RESET}")
                    
                    # Try with port exactly as provided in pairing response
                    print(f"{Fore.YELLOW}Trying with original pairing port...{Fore.RESET}")
                    alt_debug_port = port
                    connect_cmd = f"termux-adb connect {ip_address}:{alt_debug_port}"
                    connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                    if "connected" in connect_process.stdout.lower():
                        print(f"{Fore.GREEN}Successfully connected using pairing port {alt_debug_port}{Fore.RESET}")
                    else:
                        print(f"{Fore.RED}Failed to connect. Please try manually.{Fore.RESET}")
                        print(f"{Fore.YELLOW}Try manual connection: termux-adb connect {ip_address}:<PORT>{Fore.RESET}")
            else:
                print(f"{Fore.RED}Pairing failed: {process.stdout}{Fore.RESET}")
                if process.stderr:
                    print(f"{Fore.RED}Error: {process.stderr}{Fore.RESET}")
        except Exception as e:
            print(f"{Fore.RED}Error during pairing: {e}{Fore.RESET}")
            
    def update_service(self, zc, type_, name):
        pass

# Start listening for devices
print(f"{Fore.CYAN}Listening for devices...{Fore.RESET}")
print(f"{Fore.YELLOW}Press Ctrl+C to quit{Fore.RESET}")

try:
    zeroconf = Zeroconf()
    listener = ADBListener()
    browser = ServiceBrowser(zeroconf, TYPE, listener)
    
    # Keep the script running until user interrupts
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print(f"{Fore.CYAN}\nExiting...{Fore.RESET}")
finally:
    try:
        zeroconf.close()
    except:
        pass
EOF

echo -e "${GREEN}Script execution completed.${NC}"
echo -e "${CYAN}If you faced any issues, try running the individual commands:${NC}"
echo -e "${YELLOW}1. pkg update -y${NC}"
echo -e "${YELLOW}2. pkg install -y python which curl${NC}"
echo -e "${YELLOW}3. curl -s https://raw.githubusercontent.com/nohajc/termux-adb/master/install.sh | bash${NC}"
echo -e "${YELLOW}4. pip install qrcode colorama zeroconf${NC}"
