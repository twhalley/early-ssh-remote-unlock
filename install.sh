#!/bin/bash

# Script to detect if running as root and check dropbear-initramfs package

# Parse command line arguments
CUSTOM_PUBLIC_KEY=""
if [ $# -gt 0 ]; then
    CUSTOM_PUBLIC_KEY="$1"
    echo "🔑 Custom public key provided as argument"
else
    echo "🔑 No public key argument provided, will generate/use existing key"
fi

echo ""
echo "=== ROOT PRIVILEGE CHECK ==="
# Check if the effective user ID is 0 (root)
if [ "$EUID" -eq 0 ]; then
    echo "✅ This script is running as ROOT"
    echo "User: $(whoami)"
    echo "UID: $UID"
    echo "EUID: $EUID"
else
    echo "❌ This script is NOT running as root"
    echo "User: $(whoami)"
    echo "UID: $UID"
    echo "EUID: $EUID"
    echo ""
    echo "To run as root, use one of the following:"
    echo "  sudo $0 [public_key_content]"
    echo "  su -c '$0 [public_key_content]'"
fi

echo ""
echo "=== PACKAGE CHECK: dropbear-initramfs ==="

# Check if dropbear-initramfs package is installed
if dpkg -s dropbear-initramfs >/dev/null 2>&1; then
    echo "✅ dropbear-initramfs package is INSTALLED"
    
    # Get package version and status
    PACKAGE_VERSION=$(dpkg -s dropbear-initramfs 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
    PACKAGE_STATUS=$(dpkg -s dropbear-initramfs 2>/dev/null | grep "^Status:" | cut -d' ' -f4)
    
    echo "   Version: $PACKAGE_VERSION"
    echo "   Status: $PACKAGE_STATUS"
    
    # Check if the package is properly configured
    if [ "$PACKAGE_STATUS" = "installed" ]; then
        echo "   ✅ Package is properly configured"
    else
        echo "   ⚠️  Package status: $PACKAGE_STATUS"
    fi
    
    echo ""
    echo "=== DROPBEAR CONFIGURATION ==="
    
    # Check if running as root for configuration
    if [ "$EUID" -eq 0 ]; then
        # Check if /etc/dropbear/initramfs directory exists
        if [ -d "/etc/dropbear/initramfs" ]; then
            echo "✅ /etc/dropbear/initramfs directory exists"
            
            # Configure dropbear.conf
            DROPBEAR_CONF="/etc/dropbear/initramfs/dropbear.conf"
            DROPBEAR_OPTIONS='DROPBEAR_OPTIONS="-I 180 -j -k -p 2222 -s -c cryptroot-unlock"'
            
            # Create or update the configuration file
            echo "📝 Configuring $DROPBEAR_CONF..."
            echo "$DROPBEAR_OPTIONS" > "$DROPBEAR_CONF"
            
            if [ $? -eq 0 ]; then
                echo "✅ Successfully configured dropbear.conf"
                echo "   Configuration: $DROPBEAR_OPTIONS"
                echo "   File location: $DROPBEAR_CONF"
            else
                echo "❌ Failed to write configuration file"
            fi
            
            echo ""
            echo "=== SSH KEY SETUP ==="
            
            AUTHORIZED_KEYS="/etc/dropbear/initramfs/authorized_keys"
            
            # Check if custom public key was provided
            if [ -n "$CUSTOM_PUBLIC_KEY" ]; then
                echo "📝 Using provided public key..."
                
                # Validate the public key format (basic check)
                if echo "$CUSTOM_PUBLIC_KEY" | grep -q "^ssh-"; then
                    echo "✅ Public key format appears valid"
                    
                    # Write the custom public key to authorized_keys
                    echo "$CUSTOM_PUBLIC_KEY" > "$AUTHORIZED_KEYS"
                    chmod 600 "$AUTHORIZED_KEYS"
                    
                    if [ $? -eq 0 ]; then
                        echo "✅ Successfully configured authorized_keys with custom key"
                        echo "   Public key saved to: $AUTHORIZED_KEYS"
                        echo "   Key details:"
                        echo "$CUSTOM_PUBLIC_KEY" | cut -d' ' -f1-2 | head -c 50 | tr -d '\n'
                        echo "..."
                    else
                        echo "❌ Failed to write custom public key to authorized_keys"
                    fi
                else
                    echo "❌ Invalid public key format. Expected format: ssh-rsa/ssh-ed25519 [key] [comment]"
                    echo "   Falling back to key generation..."
                    CUSTOM_PUBLIC_KEY=""  # Clear to trigger fallback
                fi
            fi
            
            # Fallback to generate/use existing key if no valid custom key provided
            if [ -z "$CUSTOM_PUBLIC_KEY" ]; then
                echo "📝 Using generated/existing SSH key..."
                
                # Determine the user's home directory (in case running with sudo)
                if [ -n "$SUDO_USER" ]; then
                    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
                    ACTUAL_USER="$SUDO_USER"
                else
                    USER_HOME="$HOME"
                    ACTUAL_USER="$(whoami)"
                fi
                
                SSH_KEY_PATH="$USER_HOME/.ssh/id_rsa"
                SSH_PUB_KEY_PATH="$USER_HOME/.ssh/id_rsa.pub"
                
                # Check if SSH key already exists
                if [ -f "$SSH_PUB_KEY_PATH" ]; then
                    echo "✅ SSH public key already exists: $SSH_PUB_KEY_PATH"
                else
                    echo "📝 No SSH key found, generating new RSA key pair..."
                    
                    # Create .ssh directory if it doesn't exist
                    if [ ! -d "$USER_HOME/.ssh" ]; then
                        mkdir -p "$USER_HOME/.ssh"
                        chmod 700 "$USER_HOME/.ssh"
                        if [ -n "$SUDO_USER" ]; then
                            chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.ssh"
                        fi
                    fi
                    
                    # Generate SSH key pair
                    if sudo -u "$ACTUAL_USER" ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "dropbear-initramfs@$(hostname)"; then
                        echo "✅ Successfully generated SSH key pair"
                        echo "   Private key: $SSH_KEY_PATH"
                        echo "   Public key: $SSH_PUB_KEY_PATH"
                    else
                        echo "❌ Failed to generate SSH key pair"
                        return 1
                    fi
                fi
                
                # Copy public key to authorized_keys
                if [ -f "$SSH_PUB_KEY_PATH" ]; then
                    echo "📝 Configuring authorized_keys for dropbear..."
                    
                    # Create authorized_keys file with the public key
                    cp "$SSH_PUB_KEY_PATH" "$AUTHORIZED_KEYS"
                    chmod 600 "$AUTHORIZED_KEYS"
                    
                    if [ $? -eq 0 ]; then
                        echo "✅ Successfully configured authorized_keys"
                        echo "   Public key copied to: $AUTHORIZED_KEYS"
                        echo "   Key details:"
                        head -c 50 "$SSH_PUB_KEY_PATH" | tr -d '\n'
                        echo "..."
                    else
                        echo "❌ Failed to configure authorized_keys"
                    fi
                else
                    echo "❌ Public key file not found: $SSH_PUB_KEY_PATH"
                fi
            fi
            
        else
            echo "❌ /etc/dropbear/initramfs directory does not exist"
            echo "   The dropbear-initramfs package may not be properly installed"
        fi
        
        echo ""
        echo "=== INITRAMFS NETWORK CONFIGURATION ==="
        
        # Configure static IP in initramfs.conf
        INITRAMFS_CONF="/etc/initramfs-tools/initramfs.conf"
        IP_CONFIG="IP=172.16.246.100::172.16.246.254:255.255.255.0:dropbear-server"
        
        if [ -f "$INITRAMFS_CONF" ]; then
            echo "✅ $INITRAMFS_CONF exists"
            
            # Check if IP configuration already exists
            if grep -q "^IP=" "$INITRAMFS_CONF"; then
                echo "📝 Updating existing IP configuration..."
                # Replace existing IP line
                sed -i "s/^IP=.*/$IP_CONFIG/" "$INITRAMFS_CONF"
            else
                echo "📝 Adding new IP configuration..."
                # Add IP configuration to the file
                echo "$IP_CONFIG" >> "$INITRAMFS_CONF"
            fi
            
            if [ $? -eq 0 ]; then
                echo "✅ Successfully configured static IP"
                echo "   Configuration: $IP_CONFIG"
                echo "   File location: $INITRAMFS_CONF"
                
                # Show the current IP configuration
                echo "   Current IP setting:"
                grep "^IP=" "$INITRAMFS_CONF" | sed 's/^/      /'
                
                echo ""
                echo "=== UPDATING INITRAMFS ==="
                echo "📝 Rebuilding initramfs with new configuration..."
                
                # Update initramfs to include the new configuration
                if update-initramfs -u; then
                    echo "✅ Successfully updated initramfs"
                    echo "   The system is now configured for early SSH remote unlock"
                    echo "   Reboot to activate the new initramfs"
                else
                    echo "❌ Failed to update initramfs"
                    echo "   You may need to run 'sudo update-initramfs -u' manually"
                fi
            else
                echo "❌ Failed to configure static IP"
            fi
        else
            echo "❌ $INITRAMFS_CONF does not exist"
            echo "   initramfs-tools may not be installed properly"
        fi
        
    else
        echo "⚠️  Root privileges required for configuration"
        echo "   Run this script with sudo to configure dropbear.conf and initramfs.conf"
    fi
    
else
    echo "❌ dropbear-initramfs package is NOT installed"
    echo ""
    echo "To install dropbear-initramfs, run:"
    echo "  sudo apt update"
    echo "  sudo apt install dropbear-initramfs"
fi

echo ""
echo "=== ADDITIONAL INFORMATION ==="
echo "HOME: $HOME"
echo "USER: $USER"
echo "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')" 