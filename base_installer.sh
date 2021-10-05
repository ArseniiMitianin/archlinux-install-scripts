#!/bin/zsh

# Launch this script on a UEFI system

# Colors
function white  { tput sgr 0; }
function cyan   { tput setaf 6; echo -en $1; white; }
function green  { tput setaf 2; echo -en $1; white; }
function yellow { tput setaf 3; echo -en $1; white; }

function cpu {
    if [[ $(lscpu | grep GenuineIntel) ]]; then
        echo -n "intel"
    elif [[ $(lscpu | grep AuthenticAMD) ]]; then
        echo -n "amd"
    fi
}

function configure_pacman {
    cyan "Configuring Pacman\n"
    green "  --> Enabling colored output\n";          sed '/Color/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling verbose package listing\n"; sed '/VerbosePkgLists/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling parallel downloads\n";      sed '/ParallelDownloads/s/^#//g' -i /etc/pacman.conf
    green "  --> Enabling multilib repo\n";           sed '93,94 s/^#//' -i /etc/pacman.conf
}

function launch {
    cp $HOME/$1 /mnt
    chmod +x /mnt/$1
    arch-chroot /mnt ./$1 $2
    rm "/mnt/$1"
}

# Connect to the Internet
if [[ $(ip a | grep enp) ]]; then
    green "Found an Ethernet connection!\n"
fi

if [[ ! $(ip a | grep enp) && $(ip a | egrep '(wlan|wlp)') ]]; then
    green "Found a Wi-Fi device on your machine\n"
    yellow "Select a network device"
    iwctl device list
    echo -n "> "
    read net_device

    yellow "Which network to connect to?\n"
    iwctl station $net_device get-network
    echo -n "> "
    read network

    if [[ $(iwctl station ${net_device} connect ${network}) ]]; then
        green "Successfully connected to ${network}!"
    fi
fi

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

launch "config.sh" # Configuration

# Desktop installation (optional)
yellow "Which desktop do you want to install?\n"
green "  --> [g] GNOME\n"
green "  --> [kx] KDE Plasma (X.Org)\n"
green "  --> [kw] KDE Plasma (Wayland)\n"
green "  --> [n]  No desktop\n"
echo -n "> "
read desktop

case $desktop in
    g) launch gnome.sh ;;
    kx) launch kde.sh xorg ;;
    kw) launch kde.sh wayland ;;
esac

green "\nInstallation is complete!\nType in 'umount -R /mnt', and reboot.\n"
