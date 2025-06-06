# Early SSH Remote Unlock

A comprehensive setup script for configuring early SSH remote unlock on encrypted Linux systems using dropbear-initramfs. This allows you to remotely unlock LUKS-encrypted drives during system boot via SSH. All credit goes to https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/ I've just created a script around this piece of work.

## Overview

This script automates the configuration of:
- **Dropbear SSH Server** in initramfs for early boot access
- **Static IP Configuration** for network connectivity during boot
- **SSH Key Management** for secure authentication
- **Initramfs Updates** to apply all configurations

## Prerequisites

- **Linux system** with LUKS encryption
- **dropbear-initramfs package** (script will check and guide installation)
- **Root privileges** (sudo access)
- **Network connectivity** during boot

## Installation

1. **Clone or download** the script:
   ```bash
   git clone https://github.com/twhalley/early-ssh-remote-unlock.git
   cd early-ssh-remote-unlock
   chmod +x install.sh
   ```

2. **Run the installation** script:
   ```bash
   sudo ./install.sh
   ```

## Usage

### Basic Usage
```bash
# Use defaults (auto-generate SSH key, VMware-compatible network)
sudo ./install.sh

# Show help and available options
./install.sh --help
```

### Advanced Usage
```bash
sudo ./install.sh [public_key] [ip_address] [gateway] [netmask] [hostname]
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `public_key` | SSH public key content | Auto-generate/use existing |
| `ip_address` | Static IP for initramfs | `172.16.246.100` |
| `gateway` | Network gateway | `172.16.246.254` |
| `netmask` | Subnet mask | `255.255.255.0` |
| `hostname` | System hostname | `dropbear-server` |

## Examples

### Example 1: Default VMware Setup
```bash
sudo ./install.sh
```
- Uses existing SSH key or generates new one
- Configures IP: `172.16.246.100`
- Gateway: `172.16.246.254`

### Example 2: Custom Network Configuration
```bash
sudo ./install.sh "" 192.168.1.100 192.168.1.1 255.255.255.0 unlock-server
```
- Auto-generates SSH key (empty first parameter)
- Custom network configuration

### Example 3: Custom SSH Key + Network
```bash
sudo ./install.sh "ssh-rsa AAAAB3NzaC1yc2EAAAA... user@host" 10.0.0.50 10.0.0.1 255.255.255.0 my-server
```
- Uses provided SSH public key
- Custom network settings

## Remote Unlock Process

### 1. System Boot
When the encrypted system boots, it will:
- Load initramfs with dropbear SSH server
- Configure the specified static IP address
- Start SSH server on port **2222**

### 2. SSH Connection
From your remote machine:
```bash
ssh root@<configured_ip> -p 2222
```

### 3. Unlock Encryption
At the dropbear prompt:
```bash
cryptroot-unlock
```
Enter your LUKS passphrase when prompted.

### 4. Normal Boot
The system will continue booting normally after successful unlock.

## Network Configuration

### VMware Workstation
Default configuration works with VMware's NAT networking:
- **Network**: 172.16.246.0/24
- **VM IP**: 172.16.246.100
- **Gateway**: 172.16.246.254

### Other Environments
Adjust network parameters based on your environment:

| Environment | Typical Settings |
|-------------|------------------|
| **Home Network** | `192.168.1.x` / `192.168.1.1` |
| **Corporate** | Varies (check with IT) |
| **VirtualBox** | `10.0.2.x` / `10.0.2.2` |
| **Hyper-V** | `172.x.x.x` (varies) |

## SSH Key Management

### Automatic Key Generation
- Creates 4096-bit RSA key pair
- Saves to `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`
- Copies public key to dropbear authorized_keys

### Using Existing Keys
- Script detects existing `~/.ssh/id_rsa.pub`
- Uses existing key if found
- Maintains proper ownership when using sudo

### Custom Public Key
Provide your own public key as the first argument:
```bash
sudo ./install.sh "ssh-rsa AAAAB3NzaC1yc2EAAAA... user@host"
```

## Troubleshooting

### 1. Package Not Installed
```
❌ dropbear-initramfs package is NOT installed
```
**Solution:**
```bash
sudo apt update
sudo apt install dropbear-initramfs
```

### 2. Network Not Reachable
**Check:**
- IP address conflicts
- Network configuration matches your environment
- Firewall settings on host machine

### 3. SSH Connection Refused
**Verify:**
- System has booted to encryption prompt
- Correct IP address and port (2222)
- SSH key is properly configured

### 4. Permission Errors
**Ensure:**
- Running script with sudo
- SSH keys have correct ownership
- Authorized_keys file has proper permissions (600)

### 5. Initramfs Update Failed
**Manual update:**
```bash
sudo update-initramfs -u
```

## Security Notes

- **No Passphrase**: SSH keys are generated without passphrase for automated unlock
- **Root Access**: Dropbear provides root access for unlock functionality
- **Network Security**: Ensure network is secure during boot process
- **Key Management**: Protect private SSH keys appropriately

## File Locations

| Component | Location |
|-----------|----------|
| **Dropbear Config** | `/etc/dropbear/initramfs/dropbear.conf` |
| **Authorized Keys** | `/etc/dropbear/initramfs/authorized_keys` |
| **Network Config** | `/etc/initramfs-tools/initramfs.conf` |
| **SSH Keys** | `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` |

## What the Script Does

1. ✅ **Root Privilege Check** - Verifies sudo/root access
2. ✅ **Package Verification** - Checks dropbear-initramfs installation
3. ✅ **Dropbear Configuration** - Sets SSH server options
4. ✅ **SSH Key Setup** - Generates/configures authentication keys
5. ✅ **Network Configuration** - Sets static IP for early boot
6. ✅ **Initramfs Update** - Rebuilds initramfs with new settings

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify your network environment settings
3. Ensure all prerequisites are met
4. Check system logs for additional details

## License

This project is provided as-is for educational and practical use. 