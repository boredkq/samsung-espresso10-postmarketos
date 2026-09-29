# postmarketOS for Samsung Galaxy Tab 2 10.1 (`samsung-espresso10`)
### GT-P5100 (3G + Wi-Fi) / GT-P5110 (Wi-Fi) / GT-P5113 (Wi-Fi + IR)

[![Build postmarketOS TWRP ZIP](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml/badge.svg)](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/boredkq/samsung-espresso10-postmarketos?label=TWRP%20Release&color=success)](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest)

Порт **postmarketOS** для Samsung Galaxy Tab 2 10.1 с облачной сборкой TWRP-архивов. Основной образ использует ядро **Linux 6.1.0 `linux-openpvrsgx`** из PVRports с модулем `pvrsrvkm_omap4_sgx540_120` для PowerVR SGX540 и userspace DDK 1.17.

> [!IMPORTANT]
> Архивы успешно собираются в GitHub Actions. Работа Wi‑Fi, звука и 3D должна проверяться на реальном планшете; успешная сборка сама по себе не подтверждает работу оборудования.

---

## 📥 Готовые сборки для TWRP (Прямое скачивание)

Вам **не нужно** ничего компилировать на компьютере — готовые к прошивке через TWRP архивы автоматически собираются в облаке GitHub Actions и доступны в разделе [GitHub Releases](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest):

| Архив | Назначение | Размер | Описание | Ссылка на скачивание |
| :--- | :--- | :---: | :--- | :--- |
| **`pmos-samsung-espresso10-recovery.zip`** | **Полная ОС — рекомендуется** | **~684 МБ** | Полная установка через TWRP: postmarketOS, LXQt, PVRports userspace и PVRports-ядро с SGX540 | [⬇️ Скачать полную ОС](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pmos-samsung-espresso10-recovery.zip) |
| **`kernel-samsung-espresso10-twrp.zip`** | **Обновление ядра** | **~15 МБ** | Прошивает `boot.img`, модули `linux-openpvrsgx` и firmware BCM4330. Только для уже установленной postmarketOS, Wipe не требуется | [⬇️ Скачать ядро](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/kernel-samsung-espresso10-twrp.zip) |
| **`pvrports-samsung-espresso10-twrp.zip`** | **Только PVR userspace** | **~7 МБ** | DDK 1.17, Mesa Classic PVR DRI и OpenRC-служба. Требует уже установленное совместимое ядро `linux-openpvrsgx` | [⬇️ Скачать PVRports](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pvrports-samsung-espresso10-twrp.zip) |
| **`pmos-samsung-espresso10.zip`** | **Экспорт pmbootstrap** | **~693 МБ** | Дополнительный архив, создаваемый pmbootstrap. Для обычной установки через TWRP используйте файл с суффиксом `-recovery.zip` | [⬇️ Скачать экспорт](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pmos-samsung-espresso10.zip) |

Последняя проверенная облачная сборка: [GitHub Actions #47](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/runs/36443257504) — **успешно**.

*Логин по умолчанию:* `user`  
*Пароль по умолчанию:* `147147`

---

## 📋 Статус аппаратных компонентов

| Компонент | Исходный статус в upstream | Статус в этом порте | Техническое решение |
| :--- | :--- | :--- | :--- |
| **Звук (Audio)** | ❌ Не работал | 🧪 **Требуется проверка на устройстве** | В репозитории есть DTS/ASoC и UCM2-исправления WM1811, но текущий PVRports-образ ещё не подтверждён тестом динамиков, наушников и микрофона |
| **Wi-Fi** | ❌ Не работал / отвал при reboot | 🧪 **Требуется проверка на устройстве** | `BRCMFMAC` собран модулем; образ включает официальные firmware и NVRAM из `firmware-samsung-espresso` |
| **Wi-Fi NVRAM** | ⚠️ Предупреждения о калибровке | ✅ **Включён в образ** | Используется `brcmfmac4330-sdio.samsung,espresso10.txt` из пакета `firmware-samsung-espresso`, а не самодельный файл |
| **Память / Rootfs** | ⚠️ Тесный `FACTORYFS` (1.4 ГБ) | ✅ **12.1 ГБ** (`DATAFS`) | `deviceinfo_flash_heimdall_partition_rootfs="DATAFS"` — система устанавливается в основной раздел |
| **Батарея / Bootloop** | ❌ Бутлуп при разряде в 0% | ✅ **Защищен от бутлупа** | Профиль `UPower.conf` с порогом экстренного выключения на 6–8% емкости батареи SMB347 |
| **Графика / 3D** | ⚠️ Нет открытого драйвера SGX540 в современной Mesa | 🧪 **PVRports встроен, нужен тест** | Ядро `linux-openpvrsgx`, модуль `pvrsrvkm_omap4_sgx540_120`, DDK 1.17 и `mesa-pvr-dri-classic`; профиль выбирает `MESA_LOADER_DRIVER_OVERRIDE=pvr` только при наличии kernel-модуля и userspace |
| **Сенсорный экран** | ✅ Работает | ✅ **Работает** | Драйвер Atmel maXTouch (мультитач до 10 касаний) |
| **USB OTG / Зарядка**| ✅ Работает | ✅ **Работает** | Samsung P30 extcon драйвер (OTG-хост и зарядка) |

---

## 📲 Инструкция по установке через TWRP Recovery

### Вариант 1: Обновление PVRports-ядра без потери данных

Если у вас уже установлена postmarketOS из этого проекта и нужно обновить только ядро, модули и firmware:

1. Скачайте **`kernel-samsung-espresso10-twrp.zip`** (~15 МБ).
2. Скопируйте его на карту MicroSD (или используйте ADB Sideload).
3. Переведите планшет в TWRP (зажмите **Питание + Громкость ВНИЗ**).
4. Выберите **Install** -> выберите `kernel-samsung-espresso10-twrp.zip` -> свайпните **Swipe to confirm Flash**.
   > **Wipe делать НЕ нужно!** Установщик прошьет `boot.img` в раздел BOOT и обновит модули ядра.
5. Нажмите **Reboot System**.

---

### Вариант 2: Чистая установка полной системы postmarketOS

1. Скачайте **`pmos-samsung-espresso10-recovery.zip`** (~700 МБ) из [Releases](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest).
2. Скопируйте архив на MicroSD карту.
3. Выключите планшет. Зажмите и удерживайте кнопки **Питание + Громкость ВНИЗ** (Power + Volume Down) до появления логотипа TWRP.
4. В главном меню TWRP:
   - Перейдите в **Wipe** -> **Advanced Wipe**.
   - Отметьте галочками: `System`, `Data`, `Cache`, `Dalvik / ART Cache` (**НЕ отмечайте Micro SDCard!**).
   - Свайпните **Swipe to Wipe** для очистки.
5. Вернитесь в главное меню -> выберите **Install** -> нажмите **Select Storage** -> выберите **Micro SDCard**.
6. Выберите скачанный `.zip` файл и свайпните **Swipe to confirm Flash**.
   - Встроенный установщик автоматически разметит раздел `DATAFS` (12.1 ГБ), распакует rootfs и прошьет загрузочный образ `boot.img`.
7. По окончании нажмите **Reboot System**.

#### Через ADB Sideload (Без карты памяти):
1. В TWRP выберите: **Advanced** -> **ADB Sideload** -> свайпните для старта.
2. На компьютере выполните:
   ```bash
   adb sideload pmos-samsung-espresso10-recovery.zip
   # или для быстрого теста ядра:
   adb sideload kernel-samsung-espresso10-twrp.zip
   ```
3. Перезагрузите устройство (**Reboot System**).

---

## 🛠️ Структура репозитория

```
├── .github/workflows/
│   └── build.yml                       # CI автоматической сборки TWRP архивов ядра и postmarketOS
│
├── device-samsung-espresso10/          # Пакет устройства для postmarketOS / pmaports
│   ├── APKBUILD                        # Сборка пакета с автонастройкой звука, графики и питания
│   ├── deviceinfo                      # Описание платформы, переключение rootfs на DATAFS
│   ├── 10-omapdrm.conf                 # Конфигурация Xorg modesetting / omapdrm
│   ├── espresso-env.sh                 # Оптимизации рендеринга для PowerVR SGX540
│   ├── espresso10-sound.conf           # Конфигурация ALSA UCM2
│   ├── HiFi.conf                       # UCM2 HiFi профиль переключения динамиков/наушников
│   └── UPower.conf                     # Предотвращение глубокого разряда в 0%
│
├── linux-openpvrsgx/                    # Активное ядро Linux 6.1.0 с PVR/SGX540
│   └── APKBUILD                        # Закреплённые исходники и патчи PVRports; проверяет наличие pvrsrvkm
│
├── linux-postmarketos-omap/            # Экспериментальное mainline-ядро 7.1.5 без SGX540
│   ├── APKBUILD                        # Рецепт сборки ядра со всеми патчами
│   ├── config-postmarketos-omap.armv7  # Конфигурация ядра: BRCMFMAC=m, WM8994, OTG, P30
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
│   ├── 0012-ARM-dts-omap4-espresso-add-wm1811-audio.patch       # Звук WM1811 (точный ребейз)
│   ├── 0013-ARM-dts-omap4-espresso-fix-wifi-reboot.patch        # Фикс Wi-Fi power cycle
│   └── 0014-regulator-twl6030-add-clk32kg-support.patch        # Тактирование 32кГц TWL6030
│
└── scripts/
    ├── build_twrp_zip.sh               # Облачная сборка системы и интеграция PVRports
    ├── package_kernel_zip.sh           # Упаковка автономного kernel-twrp.zip
    ├── package_pvrports_zip.sh         # Упаковка PVR userspace для TWRP
    └── install_pvrports.sh             # Проверяемая установка PVR userspace в работающей системе
```

---

## ⚙️ Полезные команды после первого включения

### 1. Подключение к Wi-Fi
```bash
# Проверка сетевых интерфейсов (должен появиться wlan0):
ip link

# Поиск доступных Wi-Fi сетей:
nmcli dev wifi list

# Подключение к вашей точке доступа:
nmcli dev wifi connect "Имя_Сети" password "Пароль"
```

### 2. Проверка звука
```bash
# Проверка регистрации аудиокарты WM1811 в ALSA:
cat /proc/asound/cards
# Вывод: 0 [espresso10sound]: espresso10-sound - espresso10-sound

# Тест стереодинамиков:
speaker-test -c 2 -r 44100 -twav

# Управление громкостью:
alsamixer
```

### 3. Проверка свободного места
```bash
df -h /
# Должно отображаться ~11-12 ГБ свободного пространства на разделе DATAFS
```

### 4. Проверка 3D PVRports (PowerVR SGX540)

В полном `pmos-samsung-espresso10-recovery.zip` PVRports уже встроен — повторно запускать установочный скрипт не нужно. После загрузки проверьте модуль, устройство и выбранный DRI-драйвер:

```bash
find /usr/lib/modules -name 'pvrsrvkm_omap4_sgx540_120.ko*'
ls -l /dev/pvrsrvkm
echo "$MESA_LOADER_DRIVER_OVERRIDE"
glxinfo -B
```

Ожидается модуль `pvrsrvkm_omap4_sgx540_120`, устройство `/dev/pvrsrvkm` и драйвер Mesa `pvr`. Если установлен старый образ, можно отдельно прошить `kernel-samsung-espresso10-twrp.zip`, а затем `pvrports-samsung-espresso10-twrp.zip` без Wipe.

---

## 🤝 Благодарности
- Сообществу [postmarketOS](https://postmarketos.org/) за поддержку ARM mainline платформ.
- Проекту [Unlegacy-Android](https://github.com/Unlegacy-Android) за референсные наработки драйверов для OMAP4430.
- Texas Instruments и Wolfson Microelectronics за открытую документацию аудио-стека.
