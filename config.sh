#!/bin/zsh 

source functions.sh

########################################################################################################################
# HELPER FUNCTIONS                                                                                                     #
########################################################################################################################
function prompt {
    local text=$1

    local value=""
    until [[ -n $value ]]; do
        value=$(
            dialog --keep-tite --stdout --nocancel \
            --backtitle "Arch Linux Installer" \
            --title "System Configuration" \
            --inputbox $text \
            7 62
        )
    done

    echo $value
}

function install_plugins {
    # Wget's stderr is redirected to the void for now. It turned out to be a bug which has been fixed.
    # Though Wget hasn't been updated in the repo as of now. 

    local user=$1

    green "\nInstalling Oh My Zsh for '$user'\n"
    runuser -l $user -c 'wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O $HOME/omz-install.sh 2> /dev/null'
    runuser -l $user -c 'chmod +x $HOME/omz-install.sh'
    runuser -l $user -c 'sh $HOME/omz-install.sh --unattended &> /dev/null'
    runuser -l $user -c 'rm $HOME/omz-install.sh'
    
    green "Installing Zsh Syntax Highlighting for '$user'\n"
    runuser -l $user -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting &> /dev/null'

    local configs=('.config/nvim/init.vim' '.config/aliases' '.zshrc')
    
    # Downloading config files
    runuser -l $user -c 'mkdir -p $HOME/.config/nvim'
    for filepath in $configs; do
        green "Downloading $filepath for '$user'\n"
        runuser -l $user -c "wget -q https://raw.githubusercontent.com/ArseniiMitianin/linux-configs/main/$filepath"' -O $HOME/'"$filepath"' 2> /dev/null'
    done
}


########################################################################################################################
# MAIN SCRIPT                                                                                                          #
########################################################################################################################
device=$1
is_uefi=$2

cyan "Setting the timezone\n"
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime

cyan "Saving your clock time to hardware\n"
hwclock --systohc

# Set the locale
cyan "Setting the locales\n"
sed -i '177s/.//' /etc/locale.gen        # Select American English
sed -i '403s/.//' /etc/locale.gen        # Select Russian
locale-gen                               # Generale locales
echo LANG=en_US.UTF-8 > /etc/locale.conf # Set the environment variable

# This script runs in chroot, and `dialog` is not available here.
configure_pacman
pacman -Sy
if [[ -z $(pacman -Qqs ^dialog) ]]; then
    green "\nInstalling 'dialog'...\n\n"
    pacman -Sq --noconfirm --needed dialog
fi

# Prompt for a hostname from the user
hostname=$(prompt "Enter your hostname")
clear

echo $hostname > /etc/hostname

cyan "Generating /etc/hosts\n"
echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
echo -e "::1\t\tlocalhost" >> /etc/hosts
echo -e "127.0.1.1\t$hostname.localdomain\t$hostname" >> /etc/hosts

# Setting up the root account
cyan "\nSetting the root password (leave blank to disable root)\n"
passwd

# Same prompt, but for the username
username=$(prompt "Enter a name for the regular user")
clear

# Creating a regular user
cyan "Creating user account '$username'\n"
useradd -mG users,wheel -s /bin/zsh $username
passwd $username
EDITOR=nvim visudo

# Enabling services
disk_name=$(
    lsblk -ndPo PATH,MODEL,VENDOR | \
    grep $device | \
    awk -F'"' '{gsub(/ /, "", $6); printf $6 " "; printf $4 " at "; printf $2 "\n"}'
)

dialog --colors --keep-tite --stdout \
    --backtitle "Arch Linux Installer" \
    --title "System Configuration" \
    --yesno "Is \Z1$disk_name\Zn an SSD?" \
    7 62
is_ssd=$?

clear
if [[ $is_ssd -eq 0 ]]; then
    green "Enabling weekly TRIM\n"
    systemctl enable fstrim.timer &> /dev/null
fi

green "Enabling NetworkManager\n"
systemctl enable NetworkManager &> /dev/null

# Configuring GRUB
cyan "Installing and configuring GRUB\n"

# Install GRUB
if [[ $is_uefi -eq 0 ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
else
    grub-install $device
fi

sed -i 's/ \<quiet\>//g' /etc/default/grub # Disable quiet boot

# Set up suspend-on-disk (hibernation)
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\" *$/ resume=UUID=$(blkid -s UUID -o value ${device}2)\"/" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg # Generate the GRUB config file

install_plugins $username
install_plugins root

cyan "\nChanging root's shell to Zsh\n"
chsh -s /bin/zsh root

green "\nInstalling paru for AUR\n"
runuser -l $username -c 'git clone https://aur.archlinux.org/paru-bin.git &> /dev/null'
cd /home/$username/paru-bin
sudo -Su $username makepkg -sci
cd ..
rm -rf paru-bin
