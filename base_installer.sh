#!/bin/zsh

# Launch this script on a UEFI system

# Colors
function white  { tput sgr 0; }
function red    { tput setaf 1; echo -en $1; white; }
function green  { tput setaf 2; echo -en $1; white; }
function yellow { tput setaf 3; echo -en $1; white; }
function cyan   { tput setaf 6; echo -en $1; white; }

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
    arch-chroot /mnt ./$1 $2 $3
    rm "/mnt/$1"
}

# Check if the live env is booted in UEFI mode
# Needed for disk partitioning + bootloader configuration
ls /sys/firmware/efi/efivars &> /dev/null
is_uefi=$?

# Connect to the Internet
if [[ $(ip a | egrep 'enp.*:.*state UP') ]]; then
    green "\nFound an Ethernet connection!\n\n"
elif [[ $(ip a | egrep '(wlan|wlp).*:.*state UP') ]]; then
    green "\nFound a Wi-Fi connection!\n\n"
elif [[ $(ip a | egrep 'enp.*:.*state DOWN') && $(ip a | egrep '(wlan|wlp).*:.*state DOWN') ]]; then
    green "Found a Wi-Fi device on your machine\n"
    yellow "Select a network device\n"
    iwctl device list
    echo -n "> "
    read net_device

    yellow "\nWhich network to connect to?\n"
    iwctl station $net_device get-networks
    echo -n "> "
    read network

    if iwctl station ${net_device} connect ${network}; then
        green "\nSuccessfully connected to ${network}!\n\n"
    fi
else
    red "\nYou need to connect to the Internet first!\n\n"
    return 1
fi

# Select a device
fdisk -l
yellow "\nWhich drive to use? > "
read device

cyan "Synchronizing your clock with the Internet\n"
timedatectl set-ntp true # Synchronize the clock

# Partitioning the drive
cyan "Partitioning your drive\n"
if [[ $is_uefi -eq 0 ]]; then
    green "  --> The system is booted in UEFI mode. Creating a GPT partition scheme\n"
    parted --script $device \
        mklabel gpt \
        mkpart "boot" fat32 1MiB 501MiB \
        set 1 esp on \
        mkpart "swap" linux-swap 501MiB 16.5GiB \
        mkpart "root" ext4 16.5GiB 100%
else
    green "  --> The system is booted in BIOS mode. Creating an MBR partition scheme\n"
    parted --script $device \
        mklabel msdos \
        mkpart primary ext4 1MiB 501MiB \
        set 1 boot on \
        mkpart primary linux-swap 501MiB 16.5GiB \
        mkpart primary ext4 16.5GiB 100%
fi

# Formatting partitions
cyan "Formatting partitions\n"
mkfs.fat -F32 "${device}1" &> /dev/null
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

launch "config.sh" $device $is_uefi # Configuration

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
