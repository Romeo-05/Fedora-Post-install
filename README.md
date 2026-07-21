# My personal fedora linux post-installation script
<img width="936" height="538" alt="Capture d’écran du 2026-07-21 18-54-04" src="https://github.com/user-attachments/assets/f0975462-6a3d-4169-9ae7-d2d16f7de6cf" />

## Description
This script is designed to automate the post-installation process for Fedora Linux. It performs the following actions:
- System updates :
Fully updates the system
- RPMFusion :
Enables RPMFusion repositories (optional)
- Fedora packages :
Installs all Fedora packages listed in the fedora_packages.txt file
- Flatpak packages :
Installs all Flatpak packages listed in the flatpak_packages.txt file
- Third-party packages :
Installs all .rpm packages located in the third_party/ directory
- NVIDIA driver :
Installs the NVIDIA driver (optional)
- Codecs :
Installs certain multimedia codecs not provided by default in Fedora
- GNOME customization :
Modifies specific GNOME desktop settings and installs certain extensions

## Running
Run the fedora_config.sh script with sudo (and not as root; otherwise, the GNOME customizations will be applied only to the root user).
```
chmod +x fedora_config.sh
sudo bash fedora_config.sh
```
