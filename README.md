# postmarketOS для Samsung Galaxy Tab 2 10.1 (`samsung-espresso10`)
### GT-P5100 (3G + Wi-Fi) / GT-P5110 (Wi-Fi) / GT-P5113 (Wi-Fi + IR)

[![Build postmarketOS TWRP ZIP](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml/badge.svg)](https://github.com/boredkq/samsung-espresso10-postmarketos/actions/workflows/build.yml)
[![Latest Release](https://img.shields.io/github/v/release/boredkq/samsung-espresso10-postmarketos?label=TWRP%20Release&color=success)](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest)

Мой кастомный порт **postmarketOS** (на базе Alpine Linux edge) для планшета Samsung Galaxy Tab 2 10.1 на чипсете TI OMAP4430. 

Я собрал этот образ, чтобы подарить вторую жизнь легендарному планшету: полностью оживил звук через Wolfson WM1811, разогнал процессор до 1.35 ГГц, интегрировал аппаратное 3D ускорение PowerVR SGX540, настроил сжатый RAM-диск и подготовил лёгкие, летающие графические оболочки **XFCE4** и **Openbox + tint2**.

Вам **не нужно ничего компилировать на ПК** — готовые ZIP-архивы для прошивки через TWRP автоматически собираются через настроенный мной GitHub Actions CI и доступны для прямого скачивания.

---

## 🚀 Что я сделал и починил в этом порте

1. **🔊 Звук Wolfson WM1811 (динамики и наушники) — 100% РАБОТАЕТ**:
   * В апстриме звук не работал из-за неверной конфигурации пинов шины аудио. Я нашёл и исправил pinmux регистра `0x106` для шины McBSP3 в Device Tree (`PIN_INPUT | MUX_MODE1`).
   * В ядро интегрирован машинный драйвер ASoC `snd-soc-espresso` и кодек WM8994/WM1811.
   * Написаны и интегрированы эталонные конфигурации ALSA UCM2 (`HiFi.conf`): переключение звука между стереодинамиками и 3.5мм разъёмом наушников происходит автоматически и без щелчков.
2. **⚡ Разгон процессора OMAP4430 до 1.35 ГГц (+35% к стоку)**:
   * В Device Tree добавлены оверклокерские рабочие точки (OPP tables):
     * `1200000` (1.20 ГГц @ 1.388 В) — режим OPP_NITRO (+20%);
     * `1350000` (1.35 ГГц @ 1.410 В) — режим OPP_NITRO_SB (+35%).
   * Регулятор частоты по умолчанию переведён в режим `performance` — планшет работает с максимальной отзывчивостью.
3. **🖥️ Легковесные рабочие столы (XFCE4 и Openbox + tint2)**:
   * Я убрал тяжёлый и тормозной Phosh (GNOME Mobile съедал 850 МБ из 1 ГБ RAM) и заменил его на:
     * **XFCE4** (по умолчанию, ~75 МБ RAM): полноценный классический рабочий стол с меню «Пуск» (Whisker Menu), часами, треем и настройками;
     * **Openbox + tint2** (ультра-быстрый режим, ~35 МБ RAM): оставляет **>920 МБ свободной оперативной памяти** для браузера и задач.
   * Экранная клавиатура `onboard` уже настроена под палец.
4. **💾 768 МБ LZ4 ZRAM Swap (сжатая оперативная память)**:
   * Медленная старая память eMMC планшета больше не вызывает мёртвых зависаний системы при нехватке RAM. ZRAM в оперативной памяти обеспечивает плавную многозадачность.
5. **🎮 Графика и экран**:
   * Интегрирован модуль ядра `pvrsrvkm_omap4_sgx540_120` (PowerVR SGX540) и библиотеки DDK 1.17.
   * Установлен выверенный конфиг `10-omapdrm.conf` для Xorg: чистый 24-битный TrueColor без зелёных оттенков, артефактов и падений modesetting.
   * Включён плавный кинетический скролл для Firefox (`MOZ_USE_XINPUT2=1`).
6. **📶 Wi-Fi Broadcom BCM4330**:
   * Драйвер `brcmfmac` собирается модулем, в образ встроен оригинальный калибровочный файл NVRAM от Samsung (`brcmfmac4330-sdio.samsung,espresso10.txt`). Wi-Fi стабилен и не отваливается при перезагрузках.
7. **💽 Память 12.1 ГБ**:
   * Система устанавливается в полноценный раздел пользовательских данных `DATAFS` (12.1 ГБ), а не в тесный системный раздел `FACTORYFS` (1.4 ГБ).

---

## 📥 Готовые архивы для TWRP (Скачивание)

Все архивы собираются в GitHub Actions и публикуются в [GitHub Releases](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/tag/latest):

| Архив | Для чего нужен | Размер | Что внутри | Скачать |
| :--- | :--- | :---: | :--- | :--- |
| **`pmos-samsung-espresso10-recovery.zip`** | **Полная ОС (Рекомендуется)** | **~700 МБ** | Полная установка: postmarketOS, XFCE4, Openbox, ядро с разгоном 1.35 ГГц, звук WM1811, Wi-Fi, 3D | [⬇️ Скачать полную ОС](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pmos-samsung-espresso10-recovery.zip) |
| **`kernel-samsung-espresso10-twrp.zip`** | **Только ядро с разгоном** | **~15 МБ** | Прошивает `boot.img`, модули и firmware. Для тех, у кого уже установлена postmarketOS (Wipe не нужен) | [⬇️ Скачать ядро](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/kernel-samsung-espresso10-twrp.zip) |
| **`pvrports-samsung-espresso10-twrp.zip`** | **3D ускорение PVRports** | **~7 МБ** | Библиотеки SGX540 DDK 1.17 и Mesa Classic PVR DRI (уже вшиты в полную ОС) | [⬇️ Скачать PVR](https://github.com/boredkq/samsung-espresso10-postmarketos/releases/download/latest/pvrports-samsung-espresso10-twrp.zip) |

*Логин по умолчанию:* `user`  
*Пароль / PIN:* `147147`

---

## 📲 Как прошить через TWRP Recovery

### Вариант 1: Чистая установка полной системы (Рекомендуется)
1. Скачайте **`pmos-samsung-espresso10-recovery.zip`** на MicroSD карту планшета (или шейте через ADB Sideload).
2. Выключите планшет. Зажмите и держите **Питание + Громкость ВНИЗ** до появления логотипа TWRP.
3. В меню TWRP:
   * **Wipe** -> **Advanced Wipe** -> отметьте `System`, `Data`, `Cache` (**Micro SDCard НЕ отмечайте!**) -> свайп для очистки.
   * **Install** -> выберите `pmos-samsung-espresso10-recovery.zip` -> свайп для прошивки.
   * **Reboot System**.
4. Планшет загрузится в систему с готовым рабочим столом!

### Вариант 2: Обновление только ядра (без потери данных)
Если вы уже ставили мой предыдущий образ:
1. Скачайте **`kernel-samsung-espresso10-twrp.zip`**.
2. В TWRP выберите **Install** -> `kernel-samsung-espresso10-twrp.zip` -> свайп для прошивки.
   > **Wipe делать НЕ нужно!** Ваши данные и настройки сохранятся.
3. Нажмите **Reboot System**.

---

## 🔄 Как переключаться между XFCE4 и Openbox

В прошивку вшиты сразу два рабочих стола. Вы можете легко переключаться между ними через терминал планшета (или по SSH):

* **Включить XFCE4 (удобный рабочий стол, меню «Пуск»):**
  ```bash
  sudo sed -i 's/autologin-session=.*/autologin-session=xfce/g' /etc/lightdm/lightdm.conf.d/50-autologin.conf /etc/lightdm/lightdm.conf 2>/dev/null
  sudo killall lightdm
  ```

* **Включить Openbox + tint2 (максимальная скорость, ~35 МБ RAM):**
  ```bash
  sudo sed -i 's/autologin-session=.*/autologin-session=openbox/g' /etc/lightdm/lightdm.conf.d/50-autologin.conf /etc/lightdm/lightdm.conf 2>/dev/null
  sudo killall lightdm
  ```

---

## 🛠️ Полезные команды для проверки

### 1. Проверка разгона процессора (1.35 ГГц):
```bash
# Список доступных частот (должны быть 1200000 и 1350000):
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies

# Текущая частота и регулятор (должен быть performance):
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### 2. Проверка звука:
```bash
# Проверка регистрации аудиокарты WM1811:
cat /proc/asound/cards
# Вывод: 0 [espresso10sound]: espresso10-sound - espresso10-sound

# Тест динамиков стереозвуком:
speaker-test -c 2 -r 44100 -twav

# Управление громкостью через удобный интерфейс:
alsamixer
# или графический:
pavucontrol
```

### 3. Проверка ZRAM Swap и свободной памяти:
```bash
free -m
# Swap должен показывать 768 МБ сжатого zram0
```

### 4. Подключение к Wi-Fi:
```bash
# Поиск сетей:
nmcli dev wifi list

# Подключение к вашей сети:
nmcli dev wifi connect "Имя_Сети" password "Ваш_Пароль"
```

---

## ⚙️ CI / Сборка в облаке GitHub Actions

Для сборки прошивки настроен полностью автономный воркфлоу `.github/workflows/build.yml`.
* **Умное кэширование ядра**: ядро Linux компилируется только при изменении файлов в `linux-openpvrsgx/`. 
* **Экономия минут**: готовый бинарный пакет ядра кэшируется и сохраняется в релизах, поэтому повторные сборки пользовательского окружения занимают всего **3–4 минуты** вместо 48 минут!

---

## 🤝 Благодарности
* Команде [postmarketOS](https://postmarketos.org/) за потрясающую базу для мобильного Linux.
* Разработчикам [PVRports](https://gitlab.com/pvrports) за патчи PowerVR SGX540.
* Сообществу [Unlegacy-Android](https://github.com/Unlegacy-Android) за референсные наработки драйверов для OMAP4430.
