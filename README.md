# postmarketOS for Samsung Galaxy Tab 2 10.1 (`samsung-espresso10`)
### P5100 (3G+Wi-Fi) / P5110 (Wi-Fi) / P5113 (Wi-Fi + IR)

Комплексный набор исправлений и пакетов для доведения порта postmarketOS для Samsung Galaxy Tab 2 10.1 до полностью рабочего, стабильного и пригодного для повседневного использования состояния.

---

## 📋 Статус компонентов

| Компонент | Исходный статус в pmOS | Статус с нашими фиксами | Решение |
| :--- | :--- | :--- | :--- |
| **Звук (Audio)** | ❌ Не работает |  **Работает** (Динамики, Наушники, Микрофон) | DTS: привязка WM1811 к I2C1 + McBSP3 + LDO GPIO45; включен драйвер `SND_SOC_WM8994`; профили ALSA UCM2 |
| **Wi-Fi Reboot** | ❌ Ошибка перезагрузки (#1211) |  **Работает стабильно** | Убран `regulator-always-on`, добавлен `reset-gpios` в `mmc-pwrseq-simple`, добавлен TWL6030 `clk32kg` |
| **Память / Раздел** | ⚠️ Тесный `FACTORYFS` (1.4 ГБ) |  **12.1 ГБ** (`DATAFS`) | `deviceinfo_flash_heimdall_partition_rootfs="DATAFS"` |
| **Батарея / Bootloop** | ❌ Бутлуп при разряде до 0% |  **Защищен от глубокого разряда** | UPower автовыключение при 6-8%, правильная инициализация SMB347 |
| **Графика / GUI** | ⚠️ Нет 3D драйвера для SGX540 |  **Плавный 2D / Pixman** | Оптимизации `espresso-env.sh` (`LIBGL_ALWAYS_SOFTWARE=1`, `WLR_RENDERER=pixman`) |
| **Сенсорный экран** |  Работает |  Работает | Драйвер Atmel maXTouch (в ядре OMAP) |
| **USB OTG / Зарядка**|  Работает |  Работает | Патчи Samsung P30 extcon |

---

## 🛠️ Содержимое репозитория

```
├── device-samsung-espresso10/          # Обновленный пакет устройства для pmaports
│   ├── APKBUILD                        # pkgrel=1, зависимости upower, alsa-ucm-conf, установка конфигов
│   ├── deviceinfo                      # Изменен раздел rootfs с FACTORYFS на DATAFS
│   ├── espresso10-sound.conf           # Конфигурация входа ALSA UCM2
│   ├── HiFi.conf                       # UCM2 HiFi профиль переключения динамиков/наушников/микрофона
│   ├── UPower.conf                     # Настройки раннего безопасного отключения при разряде
│   └── espresso-env.sh                 # Переменные окружения для программного рендеринга (Pixman / Mesa swrast)
│
├── linux-postmarketos-omap/            # Ядро OMAP 7.1.5 (Linux mainline)
│   ├── APKBUILD                        # Добавлены патчи 0012, 0013, 0014, обновлены sha512sums
│   ├── config-postmarketos-omap.armv7  # Включены CONFIG_MFD_WM8994, CONFIG_SND_SOC_WM8994
│   ├── 0012-ARM-dts-omap4-espresso-add-wm1811-audio.patch
│   ├── 0013-ARM-dts-omap4-espresso-fix-wifi-reboot.patch
│   └── 0014-regulator-twl6030-add-clk32kg-support.patch
│
├── patches/                            # Отдельные патчи для ручного наложения
│   ├── 0012-ARM-dts-omap4-espresso-add-wm1811-audio.patch
│   ├── 0013-ARM-dts-omap4-espresso-fix-wifi-reboot.patch
│   ├── 0014-regulator-twl6030-add-clk32kg-support.patch
│   └── 0015-kernel-config-enable-wm8994.patch
│
└── reference/                          # Извлеченные исходники Android 3.0.31 Samsung (для верификации)
    ├── board_44xx_tablet.c             # Официальный pinmux и аудио-разводка
    ├── board_espresso10_muxset.c       # Pinmux для GT-P5100 / GT-P5110
    ├── board_espresso_jack.c           # Детекция наушников
    ├── board_espresso_pmic.c           # Регуляторы питания и LDO
    └── legacy_espresso_audio.c         # ALSA ASoC драйвер звука Samsung
```

---

## 🔍 Подробности исправлений

### 1. Звук (Wolfson Microelectronics WM1811 / WM8994)
В планшетах Samsung Galaxy Tab 2 10.1 используется аудиокодек **Wolfson WM1811** (семейство WM8994), подключенный по шинам:
- **Управление**: шина `I2C1`, адрес `0x1a` (в старом коде Samsung обозначался как `0x34 >> 1`).
- **Питание LDO**: GPIO 45 (`&gpio2 13`), активный высокий уровень.
- **Тактирование**: MCLK1 26 МГц от системного генератора OMAP4 через GPIO 101 (`&gpio4 5`).
- **Аудиошина (DAI)**: OMAP4 `McBSP3` в режиме I2S (выводы ABE PDM переназначены в режим McBSP3: `AP_I2S_DIN`, `AP_I2S_DOUT`, `AP_I2S_CLK`, `AP_I2S_SYNC`).

**Что сделано**:
1. Патч `0012` активирует `&mcbsp3`, добавляет узел `wm1811` на шину `&i2c1`, настраивает `simple-audio-card` и пинмукс `abe_pdm` в режим `omap4_mcbsp3`.
2. Конфиг ядра включает `CONFIG_MFD_WM8994=y`, `CONFIG_REGULATOR_WM8994=y`, `CONFIG_GPIO_WM8994=y`, `CONFIG_SND_SOC_WM8994=m`.
3. Созданы профили ALSA UCM2 (`espresso10-sound.conf` и `HiFi.conf`) для автоматического переключения громкоговорителей, разъема 3.5 мм (наушников) и микрофона при использовании PulseAudio или PipeWire.

### 2. Ошибка Wi-Fi при перезагрузке (Issue #1211)
Планшет терял Wi-Fi модуль Broadcom BCM4330 после мягкой перезагрузки (`reboot`), модуль появлялся только после полного выключения питания.
**Причина**: 
1. В `reg_espresso_wlan` стоял флаг `regulator-always-on`, из-за чего контроллер питания не сбрасывал чип.
2. В узле `wlan_pwrseq` отсутствовал пин аппаратного сброса `reset-gpios` (`&gpio4 8` / GPIO 104), из-за чего SDIO шина не могла заново инициировать handshake.
3. Опорная частота сна 32.768 кГц от микросхемы TWL6030 (`clk32kg`) отключалась ядром при перезагрузке.

**Что сделано**:
1. Патч `0013` убирает `regulator-always-on`, добавляет `reset-gpios = <&gpio4 8 GPIO_ACTIVE_LOW>;` в `wlan_pwrseq` и привязывает тактирование `clk32kg`.
2. Патч `0014` добавляет поддержку ресурса `clk32kg` в драйвер регуляторов `twl6030-regulator.c`.

### 3. Раздел `DATAFS` вместо `FACTORYFS`
Стандартный раздел `SYSTEM` / `FACTORYFS` планшета имеет объем всего **1.4 ГБ**, чего катастрофически не хватает для графического рабочего стола postmarketOS со всеми библиотеками, браузером и приложениями.
**Что сделано**:
В `deviceinfo` параметр `deviceinfo_flash_heimdall_partition_rootfs` изменен на **`"DATAFS"`** (раздел внутренней памяти объемом **12.1 ГБ**). Теперь система имеет достаточно места для установки XFCE, LibreOffice, медиаплееров и работы без сбоев из-за переполнения диска.

### 4. Защита от глубокого разряда (Bootloop при 0%)
При полном разряде батареи до 0% планшет попадал в бесконечный бутлуп зарядки: OMAP4 включался, пытался стартовать ядро, потреблял ток выше лимита контроллера заряда Summit SMB347, напряжение проседало, и планшет отключался, повторяя цикл каждые 10 секунд.
**Что сделано**:
Установлен `UPower.conf` с жесткими порогами:
- `PercentageLow=15`
- `PercentageCritical=8`
- `PercentageAction=6`
- `CriticalPowerAction=PowerOff`
Планшет корректно и безопасно завершает работу до того, как батарея разрядится до критического уровня, исключая бутлуп.

### 5. Графика: SGX540 и выбор рабочего окружения
В OMAP4430 встроен графический процессор **PowerVR SGX540**. В апстриме Mesa **нет** рабочего открытого 3D-драйвера Gallium для SGX540 (существующий экспериментальный драйвер `etnaviv`/`fd`/`pvr` не поддерживает архитектуру SGX 5-й серии).
Попытка запустить тяжелые оболочки (GNOME Shell, KDE Plasma, Phosh) приводит к компиляции шейдеров через `llvmpipe` на двух ядрах Cortex-A9, что вызывает 100% загрузку CPU, перегрев и зависание.

**Рекомендованная среда**:
- **XFCE4** (X11) — наиболее быстрая, отзывчивая и легковесная среда для OMAP4.
- **LXQt** (X11) — также работает очень плавно.
- **Sway / Wayfire** (Wayland) — запускать только с флагом `WLR_RENDERER=pixman`.

Скрипт `espresso-env.sh` (устанавливаемый в `/etc/profile.d/espresso.sh`) автоматически выставляет:
```sh
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=softpipe
export WLR_RENDERER=pixman
export QT_QUICK_BACKEND=software
```

---

## 🚀 Инструкция по сборке и установке через `pmbootstrap`

Сборка осуществляется на ПК с установленным `pmbootstrap` (Linux / WSL2):

### Шаг 1: Подготовка pmaports
Склонируйте или скопируйте файлы из данного репозитория в каталог `pmaports`:

```bash
# Определите путь к вашему pmaports (обычно ~/.local/var/pmbootstrap/cache_git/pmaports)
PMAPORTS_DIR="$(pmbootstrap config aports)"

# Скопируйте обновленные пакеты:
cp -r device-samsung-espresso10 "$PMAPORTS_DIR"/device/community/
cp -r linux-postmarketos-omap "$PMAPORTS_DIR"/device/community/
```

### Шаг 2: Сборка пакетов
```bash
# 1. Сборка ядра OMAP с нашими патчами
pmbootstrap build --arch=armv7 linux-postmarketos-omap

# 2. Сборка пакета устройства
pmbootstrap build --arch=armv7 device-samsung-espresso10
```

### Шаг 3: Инициализация образа
Запустите `pmbootstrap init` и выберите:
- **Vendor**: `samsung`
- **Device**: `espresso10`
- **User Interface**: `xfce4` (настоятельно рекомендуется для OMAP4430)
- **Extra packages**: `alsa-utils`, `pulseaudio`, `pulseaudio-utils`, `pavucontrol`, `evtest`, `htop`

### Шаг 4: Генерация образов
```bash
pmbootstrap install
```

### Шаг 5: Прошивка на планшет

1. Переведите планшет в **Download Mode**:
   - Выключите планшет.
   - Зажмите и удерживайте **Питание + Громкость ВВЕРХ** (Power + Volume Up) до появления предупреждающего экрана.
   - Нажмите **Громкость ВНИЗ** (Volume Down) для подтверждения входа в Odin / Download Mode.
   - Подключите 30-pin USB кабель к компьютеру.

2. Прошейте ядро и rootfs с помощью `pmbootstrap`:
```bash
# Прошивка ядра (в раздел BOOT)
pmbootstrap flasher flash_kernel

# Прошивка rootfs (автоматически запишется в DATAFS 12.1 ГБ)
pmbootstrap flasher flash_rootfs
```

*(Альтернативно через прямой Heimdall)*:
```bash
heimdall flash --BOOT ~/.local/var/pmbootstrap/chroot_rootfs_samsung-espresso10/boot/boot.img \
               --DATAFS ~/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/samsung-espresso10.img
```

---

## 📲 Альтернатива: Сборка и прошивка ZIP-образа для TWRP Recovery

Если на вашем планшете уже установлено кастомное рекавери **TWRP** (Team Win Recovery Project), вы можете собрать flashable ZIP и установить postmarketOS прямо из TWRP (с MicroSD-карты или через ADB Sideload) **без использования Odin / Heimdall**:

### 1. Автоматическая сборка в облаке через GitHub Actions (Без установки Linux на ПК)
Если вы не хотите устанавливать Linux или настраивать виртуальные машины:
1. Создайте репозиторий на GitHub и отправьте в него эти исходники (`git push`).
2. В репозитории на GitHub перейдите во вкладку **Actions** -> **Build postmarketOS TWRP ZIP**.
3. Нажмите **Run workflow**.
4. GitHub Actions автоматически запустит сборку в облаке Ubuntu, скомпилирует ядро и выложит готовый архив в раздел **Artifacts** для загрузки!

### 2. Автоматическая сборка локальным скриптом (Linux / WSL2):
В репозиторий добавлен готовый скрипт автоматизации:
```bash
# Сборка ZIP для установки в раздел внутренней памяти DATAFS (12.1 ГБ) с рабочим столом XFCE4:
chmod +x scripts/build_twrp_zip.sh
./scripts/build_twrp_zip.sh data xfce4

# Или для установки системы на внешнюю MicroSD-карту:
./scripts/build_twrp_zip.sh external_sd xfce4
```
Скрипт автоматически соберет ядро, пакет устройства, сгенерирует образ и экспортирует архив `pmos-samsung-espresso10.zip` в каталог `output/`.

### 2. Ручная сборка через pmbootstrap:
```bash
# 1. Генерация установочного zip-архива для TWRP
pmbootstrap install --android-recovery-zip --recovery-install-partition=data

# 2. Экспорт архива
pmbootstrap export ./output
# Будет создан файл: ./output/pmos-samsung-espresso10.zip
```
> **ВАЖНО**: Параметр `--recovery-install-partition=data` указывает установщику postmarketOS использовать раздел `data` (`DATAFS` 12.1 ГБ), а не тесный `system` (`FACTORYFS` 1.4 ГБ).

### 3. Прошивка через TWRP:

#### Вариант A: Через MicroSD-карту (Рекомендуется)
1. Скопируйте файл `pmos-samsung-espresso10.zip` на MicroSD-карту (через кардридер или прямо в TWRP по MTP).
2. Вставьте карту в планшет.
3. Выключите планшет, затем зажмите **Питание + Громкость ВНИЗ** (Power + Volume Down) для входа в TWRP.
4. В главном меню TWRP выберите **Wipe** -> **Advanced Wipe** -> отметьте **Dalvik / ART Cache**, **Cache**, **System**, **Data** (НЕ отмечайте Micro SDCard!) -> свайпните для очистки.
5. Нажмите **Install** -> выберите Storage: Micro SDCard -> выберите `pmos-samsung-espresso10.zip`.
6. Свайпните **Swipe to confirm Flash**.
   - Установщик `postmarketos-android-recovery-installer` автоматически разметит разделы `pmOS_boot` и `pmOS_root` внутри `DATAFS`, распакует rootfs и прошьет `boot.img`.
7. Нажмите **Reboot System**.

#### Вариант B: Через ADB Sideload (без SD-карты)
1. Загрузитесь в TWRP (Power + Volume Down).
2. Перейдите в **Advanced** -> **ADB Sideload** -> свайпните **Swipe to Start Sideload**.
3. Подключите планшет к ПК по USB.
4. На ПК выполните:
   ```bash
   adb sideload ./output/pmos-samsung-espresso10.zip
   ```
5. После завершения перезагрузите планшет (**Reboot System**).

---

## 🔊 Проверка и тестирование на устройстве

### 1. Проверка аудио
После загрузки войдите по SSH или откройте терминал:

```bash
# Проверка определения звуковой карты в ALSA:
cat /proc/asound/cards
# Должно отображаться:
# 0 [espresso10sound]: espresso10-sound - espresso10-sound

# Проверка распознавания аудиокодека WM1811:
dmesg | grep -i wm8994

# Тест вывода звука (динамики):
speaker-test -c 2 -r 44100 -twav

# Управление громкостью:
alsamixer -c 0
# или графически через pavucontrol
```

### 2. Проверка Wi-Fi и перезагрузки
```bash
# Проверка наличия интерфейса wlan0:
ip link show wlan0

# Подключение к сети через nmcli:
nmcli dev wifi list
nmcli dev wifi connect "MySSID" password "MyPassword"

# Проверка мягкой перезагрузки:
sudo reboot
# После загрузки Wi-Fi должен сразу же подняться без зависаний!
```

### 3. Проверка объема свободного места
```bash
df -h /
# Должно показывать около 11-12 GB на разделе rootfs!
```
