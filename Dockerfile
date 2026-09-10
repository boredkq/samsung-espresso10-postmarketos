FROM alpine:edge

# Установка зависимостей pmbootstrap
RUN apk update && apk add --no-cache \
    python3 \
    py3-pip \
    git \
    openssl \
    sudo \
    bash \
    curl \
    xz \
    zstd \
    util-linux

# Установка pmbootstrap
RUN pip install --break-system-packages pmbootstrap

# Создание пользователя для сборки (pmbootstrap не должен работать под root)
RUN adduser -D -u 1000 pmos && \
    echo "pmos ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER pmos
WORKDIR /home/pmos

# Копирование репозитория
COPY --chown=pmos:pmos . /home/pmos/fix_samsung_espresso10_port

VOLUME /home/pmos/output

CMD ["/bin/bash", "/home/pmos/fix_samsung_espresso10_port/scripts/build_twrp_zip.sh", "data", "xfce4"]
