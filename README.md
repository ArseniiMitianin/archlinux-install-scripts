# Personal Install scripts
Currently these scripts can do a base install Arch Linux with my preferred configs:
- Hard drive:
    - `/boot`: 500 MiB (UEFI - FAT32, BIOS - Ext4)
    - Swap: Same amount as RAM (needed for suspend-on-disk/hibernation)
    - `/`: Rest of free space Ext4
- Shell: Zsh

Optional desktop install available.

## How to run 

*This section is here in case if someone stumbles upon this repo. You never know. ¯\\\_(ツ)\_/¯*

The repository can be downloaded and launched by running these commands in the terminal (you need to have `git` installed):
```bash
git clone https://github.com/ArseniiMitianin/archlinux-install-scripts.git
cd archlinux-install-scripts
chmod +x install.sh
./install.sh
```

## TODOs
### Features
- [x] Interaction through TUI windows with `dialog` (in prompts)
- [ ] Add multi-GPU detection, installation of Optimus Manager for Nvidia
- [ ] Add a locale selector
- [ ] Add a timezone selector

### Things that are definitely needed
- [x] Desktops (X.Org + Wayland):
  - [x] KDE
  - [x] GNOME
- [ ] Programs for everyday use
- [ ] Development programs

### Optional stuff
- [ ] Gaming packages (Steam, Wine, Lutris, etc. etc.?)
- [ ] I'll think of something else later...
