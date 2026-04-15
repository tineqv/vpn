#!/bin/bash
# pmos-sdcard-migrate.sh - Перенос postmarketOS на SD-карту
# Для Samsung Galaxy A3 и аналогичных устройств

set -e  # Останавливаем скрипт при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Пожалуйста, запустите с sudo: sudo $0"
    exit 1
fi

# Определение устройств
print_info "Определение накопителей..."
EMMC=$(lsblk -l -o NAME,TYPE,SIZE,MODEL | grep "disk" | grep -E "mmcblk0|sda" | head -1 | awk '{print "/dev/"$1}')
SDCARD=$(lsblk -l -o NAME,TYPE,SIZE,MODEL | grep "disk" | grep "mmcblk1" | head -1 | awk '{print "/dev/"$1}')

if [ -z "$SDCARD" ]; then
    print_error "SD-карта не найдена! Вставьте SD-карту и попробуйте снова."
    exit 1
fi

print_info "Найдена внутренняя память: $EMMC"
print_info "Найдена SD-карта: $SDCARD"

# Проверка размера SD-карты
SD_SIZE=$(lsblk -b -o SIZE "$SDCARD" | tail -1)
SD_SIZE_GB=$((SD_SIZE / 1024 / 1024 / 1024))
print_info "Размер SD-карты: ${SD_SIZE_GB}GB"

if [ $SD_SIZE_GB -lt 4 ]; then
    print_error "SD-карта слишком маленькая (минимум 4GB)"
    exit 1
fi

# Подтверждение действия
echo ""
print_warning "ВНИМАНИЕ! Этот скрипт полностью перенесёт систему на SD-карту."
print_warning "Все данные на SD-карте будут УНИЧТОЖЕНЫ!"
echo ""
read -p "Продолжить? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Операция отменена."
    exit 0
fi

# Шаг 1: Размонтирование SD-карты если смонтирована
print_info "Размонтирование SD-карты..."
umount "${SDCARD}"* 2>/dev/null || true

# Шаг 2: Создание раздела на SD-карте
print_info "Создание раздела на SD-карте..."
dd if=/dev/zero of="$SDCARD" bs=1M count=10 2>/dev/null
echo -e "o\nn\np\n1\n\n\nw" | fdisk "$SDCARD" > /dev/null 2>&1

# Шаг 3: Форматирование в ext4
print_info "Форматирование SD-карты в ext4..."
mkfs.ext4 -F "${SDCARD}p1" -L pmOS_root > /dev/null 2>&1

# Шаг 4: Создание временных папок для монтирования
print_info "Монтирование SD-карты..."
mkdir -p /mnt/pmos_sdcard /mnt/pmos_backup

# Шаг 5: Резервное копирование важных файлов на внутреннюю память
print_info "Создание резервной копии /boot..."
mkdir -p /mnt/pmos_backup
cp -a /boot/* /mnt/pmos_backup/ 2>/dev/null || true

# Шаг 6: Монтирование SD-карты
mount "${SDCARD}p1" /mnt/pmos_sdcard

# Шаг 7: Копирование системы на SD-карту
print_info "Копирование системы на SD-карту (это может занять несколько минут)..."
rsync -aAXv / /mnt/pmos_sdcard/ --exclude=/mnt --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/tmp --exclude=/run --exclude=/boot 2>&1 | grep -v "skipping non-regular file"

# Шаг 8: Создание необходимых папок
print_info "Создание системных папок..."
mkdir -p /mnt/pmos_sdcard/{proc,sys,dev,tmp,boot,run,media,mnt/old_root}

# Шаг 9: Копирование /boot отдельно (важно!)
print_info "Копирование загрузочных файлов..."
cp -a /boot/* /mnt/pmos_sdcard/boot/

# Шаг 10: Исправление fstab
print_info "Настройка fstab..."
SD_UUID=$(blkid "${SDCARD}p1" -s UUID -o value)
cat > /mnt/pmos_sdcard/etc/fstab << EOF
# Корневой раздел на SD-карте
UUID=$SD_UUID / ext4 defaults 0 1

# Дополнительные разделы (раскомментируйте при необходимости)
# /dev/mmcblk0p27 /mnt/internal_data ext4 defaults 0 2
EOF

# Шаг 11: Монтирование виртуальных ФС для chroot
print_info "Подготовка окружения для пересборки initramfs..."
mount --bind /dev /mnt/pmos_sdcard/dev
mount --bind /proc /mnt/pmos_sdcard/proc
mount --bind /sys /mnt/pmos_sdcard/sys
mount --bind /tmp /mnt/pmos_sdcard/tmp

# Шаг 12: Пересборка initramfs внутри chroot
print_info "Пересборка initramfs (важный шаг)..."
chroot /mnt/pmos_sdcard /bin/bash -c "apk update > /dev/null 2>&1; mkinitfs 2>&1 || echo 'mkinitfs warning, continuing...'"

# Шаг 13: Настройка загрузчика (если есть)
if [ -f /mnt/pmos_sdcard/sbin/update-u-boot ]; then
    print_info "Обновление загрузчика..."
    chroot /mnt/pmos_sdcard /bin/bash -c "update-u-boot $SDCARD 2>/dev/null || true"
fi

# Шаг 14: Создание индикаторного файла
echo "pmOS_SDCARD_MIGRATED_$(date +%Y%m%d_%H%M%S)" > /mnt/pmos_sdcard/.sdcard_migrated

# Шаг 15: Отмонтирование
print_info "Очистка..."
umount /mnt/pmos_sdcard/dev
umount /mnt/pmos_sdcard/proc
umount /mnt/pmos_sdcard/sys
umount /mnt/pmos_sdcard/tmp
umount /mnt/pmos_sdcard

# Шаг 16: Финальное сообщение
echo ""
print_success "========================================="
print_success "Система успешно скопирована на SD-карту!"
print_success "========================================="
echo ""
print_info "Что делать дальше:"
print_info "1. Выключите телефон"
print_info "2. Убедитесь, что SD-карта вставлена"
print_info "3. Включите телефон"
print_info "4. Если загрузился с SD-карты - отлично!"
print_info "5. Если загрузился с внутренней памяти - зажмите при включении кнопку увеличения громкости"
echo ""
print_warning "Резервная копия /boot сохранена в /mnt/pmos_backup"
print_warning "После успешной загрузки с SD-карты, внутреннюю память можно очистить"
echo ""
read -p "Нажмите Enter для перезагрузки..."
reboot
