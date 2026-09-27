# postmarketOS & Ubuntu Touch for Samsung Galaxy Tab 2 10.1 (`samsung-espresso10`)
### GT-P5100 (3G + Wi-Fi) / GT-P5110 (Wi-Fi) / GT-P5113 (Wi-Fi + IR)

[![Build postmarketOS TWRP ZIP](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml/badge.svg)](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml)
[![Build Ubuntu Touch TWRP ZIP](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build_ubuntu_touch.yml/badge.svg)](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build_ubuntu_touch.yml)
[![Latest Release](https://img.shields.io/github/v/release/boredkq/samsung-espresso10-postmarketos?label=TWRP%20Release&color=success)](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest)

Комплексный набор исправлений, пакетов и CI/CD пайплайнов для сборки и запуска современных дистрибутивов **postmarketOS** (Linux Mainline 7.1.5 + XFCE4) и **Ubuntu Touch** на планшетах Samsung Galaxy Tab 2 10.1.

---

## 📥 Готовые сборки для TWRP (Прямое скачивание)

Вам **не нужно** ничего компилировать на компьютере — готовые к прошивке через TWRP архивы автоматически собираются в облаке GitHub Actions и доступны в разделе [GitHub Releases](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest):

| Прошивка | Описание | Размер | Ссылка на скачивание |
| :--- | :--- | :---: | :--- |
| **postmarketOS (XFCE4)** | Полноценный легковесный Linux (Alpine), ядро 7.1.5, ALSA звук, Wi-Fi фикс, 12.1 ГБ диск | ~725 МБ | [⬇️ Скачать pmos-samsung-espresso10-recovery.zip](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pmos-samsung-espresso10-recovery.zip) |
| **Ubuntu Touch** | Мобильная ОС с жестовым тач-интерфейсом Lomiri, оптимизированным под планшет | ~723 МБ | [⬇️ Скачать ubuntu-touch-samsung-espresso10-twrp.zip](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/ubuntu-touch-samsung-espresso10-twrp.zip) |

*Логин по умолчанию:* `user`  
*Пароль по умолчанию:* `147147`

---

## 📋 Статус аппаратных компонентов

| Компонент | Исходный статус в upstream | Статус в этом порте | Техническое решение |
| :--- | :--- | :--- | :--- |
| **Звук (Audio)** | ❌ Не работает |  **Работает** (Динамики, 3.5мм наушники, микрофон) | DTS: подключение кодека Wolfson WM1811 к шинам `I2C1` + `McBSP3` + LDO `GPIO45`; ядро: драйвер `CONFIG_SND_SOC_WM8994`; профили ALSA UCM2 |
| **Wi-Fi Reboot** | ❌ Модуль отваливался при reboot (#1211) |  **Работает стабильно** | Убран `regulator-always-on`, добавлен `reset-gpios` в `mmc-pwrseq-simple`, обеспечена непрерывная подача TWL6030 `clk32kg` |
| **Wi-Fi NVRAM** | ⚠️ Предупреждения о калибровке |  **Калиброван** | Добавлены конфигурационные файлы NVRAM (`brcmfmac4330-sdio.txt`) с параметрами антенн для espresso10 |
| **Память / Rootfs** | ⚠️ Тесный `FACTORYFS` (1.4 ГБ) |  **12.1 ГБ** (`DATAFS`) | `deviceinfo_flash_heimdall_partition_rootfs="DATAFS"` — система ставится в основной пользовательский раздел |
| **Батарея / Bootloop** | ❌ Бутлуп при разряде в 0% |  **Защищен от бутлупа** | Профиль `UPower.conf` с порогом экстренного завершения работы на 6–8% емкости батареи SMB347 |
| **Графика / GUI** | ⚠️ Нет открытого 3D драйвера SGX540 |  **Плавный 2D / Pixman + PVRports** | Оптимизации `espresso-env.sh` (`LIBGL_ALWAYS_SOFTWARE=1`, `WLR_RENDERER=pixman`), скрипт интеграции PVRports |
| **Сенсорный экран** |  Работает |  Работает | Драйвер Atmel maXTouch (мультитач до 10 касаний) |
| **USB OTG / Зарядка**|  Работает |  Работает | Samsung P30 extcon драйвер (OTG-хост и зарядка) |

---

## 🛠️ Структура репозитория

```
├── .github/workflows/
│   ├── build.yml                       # CI автоматической сборки postmarketOS TWRP ZIP
│   └── build_ubuntu_touch.yml          # CI автоматической сборки Ubuntu Touch TWRP ZIP
│
├── device-samsung-espresso10/          # Пакет устройства для postmarketOS / pmaports
│   ├── APKBUILD                        # Сборка пакета с автонастройкой звука, графики и питания
│   ├── deviceinfo                      # Описание платформы, переключение rootfs на DATAFS
│   ├── 10-omapdrm.conf                 # Конфигурация Xorg modesetting / omapdrm
│   ├── brcmfmac4330-sdio.txt           # NVRAM калибровка чипа Wi-Fi BCM4330
│   ├── brcmfmac4330-sdio-samsung-espresso10.txt
│   ├── espresso-env.sh                 # Оптимизации рендеринга для PowerVR SGX540
│   ├── espresso10-sound.conf           # Конфигурация ALSA UCM2
│   ├── HiFi.conf                       # UCM2 HiFi профиль переключения динамиков/наушников
│   └── UPower.conf                     # Предотвращение глубокого разряда в 0%
│
├── linux-postmarketos-omap/            # Ядро Linux OMAP 7.1.5 (Mainline)
│   ├── APKBUILD                        # Рецепт сборки ядра со всеми патчами
│   ├── config-postmarketos-omap.armv7  # Конфигурация ядра с поддержкой WM8994, OTG, P30
│   ├── 0001-iio-rescale-revert-logic.patch
│   ├── 0002-hsi-dma-fix.patch
│   ├── 0003-Add-TWL6030-power-button-support-to-twl-pwrbutton.patch
│   ├── 0004-arm-dts-Add-barnesnoble-encore-support.patch
│   ├── 0005-panel-Add-lg-ld070ws1-for-barnesnoble-encore.patch
│   ├── 0006-omap4-cfi.patch
│   ├── 0007-dt-bindings-extcon-add-Samsung-P30-connector.patch
│   ├── 0008-extcon-add-Samsung-P30-connector-driver.patch
│   ├── 0009-usb-musb-omap2430-handle-initial-ID-ground-transitio.patch
│   ├── 0010-usb-phy-twl6030-add-extcon-and-external-VBUS-support.patch
│   ├── 0011-ARM-dts-omap4-espresso-add-USB-OTG-support.patch
│   ├── 0012-ARM-dts-omap4-espresso-add-wm1811-audio.patch       # Звук WM1811
│   ├── 0013-ARM-dts-omap4-espresso-fix-wifi-reboot.patch        # Фикс Wi-Fi reboot
│   └── 0014-regulator-twl6030-add-clk32kg-support.patch        # Тактирование 32кГц TWL6030
│
├── scripts/
│   ├── build_twrp_zip.sh               # Автоматизированный скрипт сборки postmarketOS TWRP ZIP
│   ├── build_ubuntu_touch_zip.sh       # Автоматизированный скрипт сборки Ubuntu Touch TWRP ZIP
│   └── install_pvrports.sh             # Скрипт установки драйверов PowerVR SGX540
│
└── reference/                          # Референсные исходники ядра Samsung для сверки распиновки
```

---

## 📲 Инструкция по установке через TWRP Recovery

### Требования:
- Планшет **Samsung Galaxy Tab 2 10.1** (GT-P5100, GT-P5110 или GT-P5113).
- Установленное кастомное рекавери **TWRP** (рекомендуется версия 3.x).
- MicroSD карта памяти (от 2 ГБ) **ИЛИ** установленный на компьютере `adb`.

### Пошаговая прошивка:

#### Способ 1: С карты памяти MicroSD (Самый простой)
1. Скачайте желаемый `.zip` архив из [Releases](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest):
   - `pmos-samsung-espresso10-recovery.zip` (для postmarketOS)
   - `ubuntu-touch-samsung-espresso10-twrp.zip` (для Ubuntu Touch)
2. Скопируйте архив на MicroSD карту.
3. Выключите планшет. Зажмите и удерживайте кнопки **Питание + Громкость ВНИЗ** (Power + Volume Down, качелька ближе к кнопке питания) до появления логотипа TWRP.
4. В главном меню TWRP:
   - Перейдите в **Wipe** -> **Advanced Wipe**.
   - Отметьте галочками: `System`, `Data`, `Cache`, `Dalvik / ART Cache` (**НЕ отмечайте Micro SDCard!**).
   - Свайпните **Swipe to Wipe** для очистки.
5. Вернитесь в главное меню -> выберите **Install** -> нажмите **Select Storage** -> выберите **Micro SDCard**.
6. Выберите скачанный `.zip` файл и свайпните **Swipe to confirm Flash**.
   - Встроенный установщик автоматически разметит раздел `DATAFS` (12.1 ГБ), распакует rootfs и прошьет загрузочный образ `boot.img`.
7. По окончании нажмите **Reboot System**.

#### Способ 2: Через ADB Sideload (Без карты памяти)
1. Загрузите планшет в TWRP (Power + Volume Down).
2. Подключите планшет к ПК через 30-pin кабель.
3. В TWRP выберите: **Advanced** -> **ADB Sideload** -> свайпните для старта.
4. На компьютере выполните команду:
   ```bash
   adb sideload pmos-samsung-espresso10-recovery.zip
   ```
5. Дождитесь передачи и распаковки (до 100%), затем перезагрузите устройство (**Reboot System**).

---

## 💻 Локальная сборка на ПК (Linux / WSL2)

Если вы хотите внести собственные изменения в ядро или пакеты и собрать образ самостоятельно:

```bash
# 1. Установите зависимости и pmbootstrap
sudo apt update && sudo apt install -y git python3 python3-pip openssl qemu-user-static binfmt-support
git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git /tmp/pmbootstrap
sudo ln -sf /tmp/pmbootstrap/pmbootstrap.py /usr/local/bin/pmbootstrap

# 2. Клонируйте этот репозиторий
git clone https://github.com/boredkq/samsung-espresso10-postmarketos.git
cd samsung-espresso10-postmarketos

# 3. Запустите сборку postmarketOS TWRP ZIP (на раздел data 12.1 ГБ с XFCE4):
chmod +x scripts/build_twrp_zip.sh
./scripts/build_twrp_zip.sh data xfce4

# Или сборку Ubuntu Touch:
chmod +x scripts/build_ubuntu_touch_zip.sh
./scripts/build_ubuntu_touch_zip.sh
```
Готовые архивы будут сохранены в каталоге `output/`.

---

## ⚙️ Полезные команды после первого включения

### 1. Подключение к Wi-Fi
```bash
# Поиск сетей:
nmcli dev wifi list

# Подключение:
nmcli dev wifi connect "Имя_Сети" password "Пароль"
```

### 2. Проверка звука
```bash
# Проверка детекции аудиокодека WM1811:
cat /proc/asound/cards
# Вывод: 0 [espresso10sound]: espresso10-sound - espresso10-sound

# Тест стереодинамиков:
speaker-test -c 2 -r 44100 -twav

# Управление громкостью:
alsamixer
# или графически через pavucontrol
```

### 3. Проверка свободного места
```bash
df -h /
# Должно отображаться ~11-12 ГБ свободного пространства на разделе DATAFS
```

---

## 🤝 Благодарности
- Сообществу [postmarketOS](https://postmarketos.org/) за поддержку ARM mainline платформ.
- Проекту [Unlegacy-Android](https://github.com/Unlegacy-Android) за референсные наработки драйверов для OMAP4430.
- Texas Instruments и Wolfson Microelectronics за открытую документацию аудио-стека.
