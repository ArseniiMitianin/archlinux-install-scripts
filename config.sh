#!/bin/bash

device=$1

# Colors
white() {
    tput sgr 0
}

cyan() {
    tput setaf 6
    echo -en $1
    white
}

green() {
    tput setaf 2
    echo -en $1
    white
}

yellow() {
    tput setaf 3
    echo -en $1
    white
}

configure_pacman() {
    cyan "Configuring Pacman\n"
    green "  --> Enabling colored output\n";          sed '/Color/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling verbose package listing\n"; sed '/VerbosePkgLists/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling parallel downloads\n";      sed '/ParallelDownloads/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling multilib repo\n";           sed '93,94 s/^#//' -i /etc/pacman.conf
}

cyan "Setting the timezone\n"
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime

cyan "Saving your clock time to hardware\n"
hwclock --systohc

# Set the locale
cyan "Setting the locales\n"
sed '/en_US.UTF-8/s/^#//g' -i /etc/locale.gen # Select American English
sed '/ru_RU.UTF-8/s/^#//g' -i /etc/locale.gen # Select Russian
locale-gen                                    # Generale locales
echo LANG=en_US.UTF-8 > /etc/locale.conf      # Set the environment variable

# Set the hostname
yellow "\nEnter your hostname >  "
read hostname
echo $hostname > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$hostname.localdomain\t$hostname" > /etc/hosts

# Set the root password
cyan "\nSetting the root password\n"
passwd

# Set up a regular user
cyan "\nAdding user 'mitianin'\n"
useradd -mG users,wheel -s /bin/zsh mitianin
passwd mitianin
EDITOR=nvim visudo

# Enabling services
yellow "\nIs your selected drive an SSD? [y/n] >  "
read answer
if [[ $answer == 'y' || $answer == 'Y' ]]; then
    green "  --> Enabling TRIM\n"
    systemctl enable fstrim.timer # Enable weekly TRIMming
fi

green "  --> Enabling NetworkManager\n"
systemctl enable NetworkManager # Enable NetworkManager > Connect to the Internet with nmtui

# Enable preferred options for Pacman
configure_pacman

# Configuring GRUB
cyan "Installing and configuring GRUB\n"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck # Install GRUB
sed -i 's/ \<quiet\>//g' /etc/default/grub                                            # Disable quiet boot

# Set up suspend-on-disk (hibernation)
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ resume=UUID=$(blkid -s UUID -o value ${device}2)\"/" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg # Generate the config file

green "Installation is complete!\nType in 'umount -R /mnt', and reboot.\n" 