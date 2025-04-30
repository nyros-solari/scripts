#!/data/data/com.termux/files/usr/bin/python
"""
Termux ADB Wireless Debugging
Generate QR code and pair Android devices for wireless debugging
For use with Termux app
"""
import os
import logging
import subprocess
import time
from random import randint
import sys

# Set up basic logging
logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

# Check and install required packages if needed
def check_and_install_packages():
    required_packages = ["qrcode", "colorama", "zeroconf"]
    missing_packages = []
    
    # Check which packages are missing
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    # Install missing packages
    if missing_packages:
        logger.info("Installing required packages: %s", ", ".join(missing_packages))
        subprocess.run([
            "pip", "install"
        ] + missing_packages, check=True)
        logger.info("Required packages installed.")
        
        # Restart script to use newly installed packages
        os.execv(sys.executable, ['python'] + sys.argv)

# Check and install termux-adb if not available
def check_termux_adb():
    if not subprocess.run(["which", "adb"], stdout=subprocess.PIPE).stdout:
        logger.info("Installing Android Debug Bridge tools...")
        try:
            # Update package lists first
            subprocess.run(["pkg", "update"], check=True)
            # Install Android tools package
            subprocess.run(["pkg", "install", "android-tools"], check=True)
            
            if not subprocess.run(["which", "adb"], stdout=subprocess.PIPE).stdout:
                logger.error("Could not install ADB. Please install manually with 'pkg install android-tools'")
                sys.exit(1)
        except subprocess.CalledProcessError:
            logger.error("Error installing packages. Please run 'pkg update && pkg install android-tools' manually.")
            sys.exit(1)

def main():
    # Install required packages if needed
    check_and_install_packages()
    
    # Now we can safely import these
    import qrcode
    from colorama import Fore, init as colorama_init
    from zeroconf import Zeroconf, ServiceBrowser, ServiceListener, ServiceInfo, IPVersion
    
    colorama_init()
    
    # Check for adb
    check_termux_adb()
    
    # Constants
    TYPE = "_adb-tls-pairing._tcp.local."
    NAME = "debug"
    PASSWORD = randint(100000, 999999)
    FORMAT_QR = f"WIFI:T:ADB;S:{NAME};P:{PASSWORD};;"
    
    # Create and display QR code
    qr = qrcode.QRCode()
    qr.add_data(FORMAT_QR)
    qr.make(fit=True)
    
    print(f"{Fore.CYAN}=== Termux ADB Wireless Debug ===={Fore.RESET}")
    print(f"{Fore.YELLOW}Pairing code: {PASSWORD}{Fore.RESET}")
    
    # Print QR code
    qr.print_ascii(invert=True)
    
    print(f"{Fore.YELLOW}Scan QR code with your device to pair{Fore.RESET}")
    print(f"{Fore.CYAN}[System]{Fore.WHITE}->{Fore.CYAN}[Developer options]{Fore.WHITE}->{Fore.CYAN}[Wireless debugging]{Fore.WHITE}->{Fore.CYAN}[Pair device with QR code]{Fore.RESET}")
    
    # Setup zeroconf for service discovery
    class ADBListener(ServiceListener):
        def remove_service(self, zc, type_, name):
            logger.debug(f"Service {name} removed")
            
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
                
                # Using standard adb command for Termux
                cmd = f"adb pair {ip_address}:{port} {PASSWORD}"
                process = subprocess.run(cmd.split(), capture_output=True, text=True)
                
                if "Successfully paired" in process.stdout:
                    print(f"{Fore.GREEN}Successfully paired with {ip_address}:{port}{Fore.RESET}")
                    # The debugging port is typically the pairing port minus 1
                    print(f"{Fore.YELLOW}Now connect using: adb connect {ip_address}:{port-1}{Fore.RESET}")
                    
                    # Try to connect automatically
                    connect_cmd = f"adb connect {ip_address}:{port-1}"
                    connect_process = subprocess.run(connect_cmd.split(), capture_output=True, text=True)
                    if "connected" in connect_process.stdout.lower():
                        print(f"{Fore.GREEN}Successfully connected to {ip_address}:{port-1}{Fore.RESET}")
                    else:
                        print(f"{Fore.YELLOW}Manual connection may be required: {connect_process.stdout}{Fore.RESET}")
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

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nScript terminated by user.")
    except Exception as e:
        print(f"Error: {str(e)}")
        print("If this is a package-related error, try running these commands manually:")
        print("pkg update")
        print("pkg install python android-tools")
        print("pip install qrcode colorama zeroconf")
