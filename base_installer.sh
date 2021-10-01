#!/bin/zsh

# Launch this script on a UEFI system while being connected to the Internet
# I couldn't figure out how to do it programmatically.

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

cpu() {
    if [[ $(lscpu | grep GenuineIntel) ]]; then
        echo -n "intel"
    elif [[ $(lscpu | grep AuthenticAMD) ]]; then
        echo -n "amd"
    fi
}

configure_pacman() {
    cyan "Configuring Pacman\n"
    green "  --> Enabling colored output\n";          sed '/Color/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling verbose package listing\n"; sed '/VerbosePkgLists/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling parallel downloads\n";      sed '/ParallelDownloads/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling multilib repo\n";           sed '93,94 s/^#//' -i /etc/pacman.conf
}

# Select a device
fdisk -l
yellow "\nWhich drive to use? > "
read device

cyan "Synchronizing your clock with the Internet\n"
timedatectl set-ntp true # Synchronize the clock

# Partitioning the drive
cyan "Partitioning your drive\n"
parted --script $device \
    mklabel gpt \
    mkpart "boot" fat32 1MiB 501MiB \
    set 1 esp on \
    mkpart "swap" linux-swap 501MiB 16.5GiB \
    mkpart "root" ext4 16.5GiB 100%

# Formatting partitions
cyan "Formatting partitions\n"
mkfs.vfat "${device}1" &> /dev/null
mkswap "${device}2" &> /dev/null
swapon "${device}2" &> /dev/null
mkfs.ext4 "${device}3" &> /dev/null

# Mounting partitions
cyan "Mounting partitions\n"
mount "${device}3" /mnt
mkdir /mnt/boot
mount "${device}1" /mnt/boot

configure_pacman

# Installing
pacstrap -i /mnt base base-devel linux linux-firmware $(cpu)-ucode man-db man-pages texinfo networkmanager grub efibootmgr mtools dosfstools neovim git zsh

cyan "Generating the file system table\n"
genfstab -U /mnt >> /mnt/etc/fstab # Generate the file system table

# Configuration
cp ~/config.sh /mnt
chmod +x /mnt/config.sh
arch-chroot /mnt ./config.sh $device

# Cleanup
rm /mnt/config.sh
