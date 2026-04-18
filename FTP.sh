#!/bin/bash

# ============================================
# АВТОМАТИЧЕСКИЙ ПЕРЕНОС СИСТЕМЫ
# С раздела mmcblk0p24 на mmcblk0p27
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Конфигурация
SOURCE_PART="/dev/mmcblk0p24"
TARGET_PART="/dev/mmcblk0p27"

log "=== ПРОВЕРКА РАЗДЕЛОВ ==="

# Проверка существования разделов
if [ ! -b "$SOURCE_PART" ]; then
    error "Исходный раздел $SOURCE_PART не найден!"
fi

if [ ! -b "$TARGET_PART" ]; then
    error "Целевой раздел $TARGET_PART не найден!"
fi

success "Разделы найдены"

# Проверка размера целевого раздела
TARGET_SIZE=$(blockdev --getsize64 "$TARGET_PART")
TARGET_SIZE_GB=$((TARGET_SIZE / 1024 / 1024 / 1024))
log "Размер целевого раздела: ${TARGET_SIZE_GB} GB"

log "=== МОНТИРОВАНИЕ ЦЕЛЕВОГО РАЗДЕЛА ==="

# Создание точки монтирования
mkdir -p /mnt/new-root

# Монтирование целевого раздела
mount "$TARGET_PART" /mnt/new-root

log "=== КОПИРОВАНИЕ СИСТЕМЫ ==="
warn "Это займёт несколько минут..."

rsync -aAXv / /mnt/new-root --exclude={
    /dev/*,
    /proc/*,
    /sys/*,
    /tmp/*,
    /run/*,
    /mnt/*,
    /media/*,
    /lost+found
} --progress

success "Копирование завершено"

log "=== НАСТРОЙКА НОВОЙ СИСТЕМЫ ==="

# Монтирование системных директорий для chroot
mount --bind /dev /mnt/new-root/dev
mount --bind /proc /mnt/new-root/proc
mount --bind /sys /mnt/new-root/sys

# Обновление fstab в новой системе
log "Обновление fstab..."
chroot /mnt/new-root /bin/bash << EOF
# Получение UUID целевого раздела
NEW_UUID=\$(blkid $TARGET_PART -s UUID -o value)

# Замена UUID в fstab
if [ -f /etc/fstab ]; then
    sed -i "s|UUID=[a-f0-9-]* /|UUID=\$NEW_UUID /|g" /etc/fstab
    echo "fstab обновлён"
else
    echo "/dev/$TARGET_PART / ext4 defaults 0 1" > /etc/fstab
fi

# Обновление загрузочных параметров (для lk2nd)
if [ -f /boot/extlinux.conf ]; then
    sed -i "s|root=/dev/mmcblk0p24|root=$TARGET_PART|g" /boot/extlinux.conf
    echo "extlinux.conf обновлён"
fi

# Создание скрипта для фиксации загрузки
cat > /usr/local/bin/fix_boot.sh << 'SCRIPT'
#!/bin/sh
# Фиксация загрузки с нового раздела
echo "Загрузка с раздела $TARGET_PART" > /dev/kmsg
SCRIPT

chmod +x /usr/local/bin/fix_boot.sh
EOF

success "Настройка завершена"

log "=== ОЧИСТКА ==="

# Размонтирование системных директорий
umount /mnt/new-root/dev
umount /mnt/new-root/proc
umount /mnt/new-root/sys
umount /mnt/new-root

success "=========================================="
success "ПЕРЕНОС ЗАВЕРШЁН"
success "=========================================="
echo ""
echo "📱 Теперь:"
echo "   1. Перезагрузите телефон: sudo reboot"
echo "   2. Во время перезагрузки зажмите ГРОМКОСТЬ ВНИЗ"
echo "   3. В lk2nd выберите 'Boot from recovery'"
echo "   4. После загрузки проверьте: df -h /"
echo ""
warn "Если телефон не загружается:"
echo "   - Перепрошейте boot.img через fastboot"
echo "   - Или выберите в lk2nd загрузку с исходного раздела"
