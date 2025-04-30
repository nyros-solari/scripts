#!/data/data/com.termux/files/usr/bin/bash

# Self-contained wireless debugging script using termux-adb
# Just paste this entire script into Termux and press Enter to run

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Android Wireless Debug using termux-adb ===${NC}"

# Install only Python packages (no android-tools)
pip install qrcode colorama zeroconf

# Create and run the Python script
python - << 'EOF'
#!/data/data/com.termux/files/usr/bin/python
import os
import subprocess
import time
from random import randint
import sys

# Check if termux-adb exists
try:
    subprocess.run(["which", "termux-adb"], check=True, stdout=subprocess.PIPE)
except subprocess.CalledProcessError:
    print("Error: termux-adb not found. Please ensure it's installed and in your PATH.")
    sys.exit(1)

# Now import the installed packages
import qrcode
from colorama import Fore, init as colorama_init
from zeroconf import Zeroconf, ServiceBrowser, ServiceListener, ServiceInfo, IPVersion

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
                # The debugging port is typically the pairing port minus 1
                print(f"{Fore.YELLOW}Now connecting using: termux-adb connect {ip_address}:{port-1}{Fore.RESET}")
                
                # Try to connect automatically with termux-adb
                connect_cmd = f"termux-adb connect {ip_address}:{port-1}"
                connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                if "connected" in connect_process.stdout.lower():
                    print(f"{Fore.GREEN}Successfully connected to {ip_address}:{port-1}{Fore.RESET}")
                    print(f"{Fore.CYAN}You can now use termux-adb commands with this device{Fore.RESET}")
                    print(f"{Fore.YELLOW}Example: termux-adb devices{Fore.RESET}")
                else:
                    print(f"{Fore.YELLOW}Connection response: {connect_process.stdout}{Fore.RESET}")
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
