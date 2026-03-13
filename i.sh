#!/bin/bash
# Автоматизация для Lenovo G50-30 (Hyprland + User + Fixes)

# 1. Форматирование
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/efi

# 2. Установка системы + Драйверы Intel + Hyprland
# Добавил seatd и polkit (нужны для запуска Wayland от пользователя)
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode nano git sudo mesa xf86-video-intel hyprland i3-wm kitty waybar networkmanager seatd polkit

# 3. Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 4. Настройка внутри системы
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "ffeflin-laptop" > /etc/hostname

# Пользователь uraac и права
useradd -m -G wheel,video,input -s /bin/bash uraac
echo "uraac:hh8A7us!" | chpasswd
echo "root:hh8A7us!" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Включаем нужные сервисы
systemctl enable NetworkManager
systemctl enable seatd

# Настройка UKI (Unified Kernel Image)
mkdir -p /etc/kernel
echo "root=PARTUUID=\$(blkid -s PARTUUID -o value /dev/sda2) rw quiet" > /etc/kernel/cmdline

# Правим пресет для генерации UKI
sed -i 's|#default_uki="/vmlinuz-linux"|default_uki="/efi/EFI/Linux/arch-zen.efi"|' /etc/mkinitcpio.d/linux-zen.preset

mkdir -p /efi/EFI/Linux
mkinitcpio -P

# Резервный путь загрузки (на случай если UEFI Lenovo сбросит настройки)
mkdir -p /efi/EFI/BOOT
cp /efi/EFI/Linux/arch-zen.efi /efi/EFI/BOOT/BOOTX64.EFI

# Запись в NVRAM
pacman -S --noconfirm efibootmgr
efibootmgr --create --disk /dev/sda --part 1 --label "Arch Zen" --loader 'EFI\Linux\arch-zen.efi' --unicode
EOF

echo "Установка завершена! После ребута логинься как uraac и вводи 'Hyprland'."
