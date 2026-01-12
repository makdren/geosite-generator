#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурационный файл
CONFIG_FILE="/root/dlcgen_config"
WORK_DIR="/root/dlcgen"
SCRIPT_NAME="dlcgen"
INSTALL_DIR="/usr/local/bin"
SCRIPT_URL="https://raw.githubusercontent.com/makdren/geosite-generator/main/dlcgen.sh"

# Ошибка/Нет ошибки
print_error() {
    echo -e "${RED}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Информация 
print_info() {
    echo -e "${BLUE}$1${NC}"
}

# Предупреждения 
print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Функция простой установки в PATH (работает при любом способе запуска)
install_to_path_simple() {
    echo -e "${YELLOW}=== УСТАНОВКА В СИСТЕМНЫЙ PATH ===${NC}"
    
    print_info "Скачиваю скрипт в $INSTALL_DIR/$SCRIPT_NAME..."
    
    # Пробуем скачать напрямую
    if wget -qO "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL" 2>/dev/null; then
        print_success "✓ Скрипт скачан через wget"
    elif curl -s -o "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL"; then
        print_success "✓ Скрипт скачан через curl"
    else
        # Пробуем с sudo
        print_warning "Пробую с sudo..."
        if sudo wget -qO "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL" 2>/dev/null; then
            print_success "✓ Скрипт скачан через sudo wget"
        elif sudo curl -s -o "$INSTALL_DIR/$SCRIPT_NAME" "$SCRIPT_URL"; then
            print_success "✓ Скрипт скачан через sudo curl"
        else
            print_error "✗ Не удалось скачать скрипт"
            return 1
        fi
    fi
    
    # Устанавливаем права
    if chmod +x "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null; then
        print_success "✓ Права установлены"
    elif sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null; then
        print_success "✓ Права установлены через sudo"
    else
        print_error "✗ Не удалось установить права"
        return 1
    fi
    
    # Проверяем установку
    if [ -x "$INSTALL_DIR/$SCRIPT_NAME" ]; then
        print_success "✓ Установка завершена!"
        print_info "Теперь используйте команду: $SCRIPT_NAME"
        
        # Сохраняем информацию об установке
        if [ -f "$CONFIG_FILE" ]; then
            echo "INSTALLED_PATH=$INSTALL_DIR/$SCRIPT_NAME" >> "$CONFIG_FILE"
            echo "INSTALL_DATE=$(date)" >> "$CONFIG_FILE"
        fi
        
        return 0
    else
        print_error "✗ Скрипт не установлен корректно"
        return 1
    fi
}

# Функция проверки и предложения установки
check_and_offer_install() {
    if ! command -v "$SCRIPT_NAME" &> /dev/null; then
        echo ""
        print_warning "Скрипт не установлен в системный PATH"
        print_info "Вы можете установить его для удобного использования командой '$SCRIPT_NAME'"
        read -p "Установить в системный PATH? (Y/n): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if install_to_path_simple; then
                # После установки спрашиваем, запустить ли установленную версию
                echo ""
                read -p "Запустить установленную версию? (Y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    # Запускаем установленную версию
                    exec dlcgen "$@"
                    exit 0
                fi
            fi
        fi
    else
        print_info "✓ Команда '$SCRIPT_NAME' уже доступна в системе"
    fi
}

# Функция удаления из PATH
uninstall_from_path() {
    echo -e "${YELLOW}=== УДАЛЕНИЕ ИЗ СИСТЕМНОГО PATH ===${NC}"
    
    # Проверяем, установлен ли скрипт
    if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
        print_info "Найден установленный скрипт: $INSTALL_DIR/$SCRIPT_NAME"
        
        read -p "Удалить скрипт из системного PATH? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if rm -f "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null; then
                print_success "✓ Скрипт удален из $INSTALL_DIR"
            else
                if sudo rm -f "$INSTALL_DIR/$SCRIPT_NAME" 2>/dev/null; then
                    print_success "✓ Скрипт удален с использованием sudo"
                else
                    print_error "✗ Не удалось удалить скрипт"
                fi
            fi
        else
            print_info "Удаление отменено"
        fi
    else
        print_info "Скрипт не найден в системном PATH"
    fi
}

# Функция быстрого поиска и удаления dlc.dat файлов
find_and_remove_dlc_files() {
    echo -n "Ищем и удаляем файлы dlc.dat... "
    
    # Ищем только в вероятных местах (быстрее)
    local likely_dirs=(
        "/root"
        "/home"
        "/tmp"
        "/var"
        "/opt"
        "$WORK_DIR"
    )
    
    local found_files=()
    
    # Ищем файлы в вероятных директориях
    for dir in "${likely_dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d $'\0' file; do
                found_files+=("$file")
            done < <(find "$dir" -name "dlc.dat" -type f 2>/dev/null | head -20)
        fi
    done
    
    # Удаляем найденные файлы
    for file in "${found_files[@]}"; do
        rm -f "$file" 2>/dev/null
    done
    
    # Также ищем в рабочей директории (глубокий поиск, но только в одной директории)
    if [ -d "$WORK_DIR" ]; then
        find "$WORK_DIR" -name "*.dat" -type f -delete 2>/dev/null
    fi
    
    print_success "✓ Удалено (найдено: ${#found_files[@]})"
}

# Функция самоочистки (удаление скрипта и всех связанных файлов)
self_cleanup() {
    echo -e "${YELLOW}=== САМООЧИСТКА СКРИПТА ===${NC}"
    echo ""
    
    print_warning "ВНИМАНИЕ: Эта операция удалит:"
    echo "  1. Команду dlcgen (если установлена)"
    echo "  2. Рабочую директорию: $WORK_DIR"
    echo "  3. Конфигурационный файл: $CONFIG_FILE"
    echo "  4. Все сгенерированные файлы"
    echo ""
    
    read -p "Вы уверены, что хотите удалить скрипт и все связанные файлы? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Отмена операции самоочистки"
        return 0
    fi
    
    echo -e "${YELLOW}Начинаем удаление...${NC}"
    
    # 1. Удаление из системного PATH
    uninstall_from_path
    
    # 2. Удаление рабочей директории
    if [ -d "$WORK_DIR" ]; then
        echo -n "Удаляем рабочую директорию $WORK_DIR... "
        rm -rf "$WORK_DIR"
        print_success "✓ Удалено"
    else
        echo "✓ Рабочая директория не существует"
    fi
    
    # 3. Удаление конфигурационного файла
    if [ -f "$CONFIG_FILE" ]; then
        echo -n "Удаляем конфигурационный файл $CONFIG_FILE... "
        rm -f "$CONFIG_FILE"
        print_success "✓ Удалено"
    else
        echo "✓ Конфигурационный файл не существует"
    fi
    
    # 4. Поиск и удаление файлов dlc.dat (ускоренная версия)
    find_and_remove_dlc_files
    
    # 5. Удаление временных файлов Docker (если создавались)
    echo -n "Очищаем временные файлы... "
    rm -rf /tmp/dlcgen_* 2>/dev/null
    print_success "✓ Удалено"
    
    echo ""
    print_success "✓ Очистка завершена успешно!"
    print_info "Все файлы скрипта dlcgen удалены из системы."
    
    # Если скрипт был запущен через curl/wget, просто выходим
    if [ "$0" = "bash" ]; then
        print_info "Скрипт был запущен через 'bash -c', файл не сохранен на диске."
        exit 0
    fi
    
    # Если скрипт сохранен в файле, удаляем его
    if [ -f "$0" ]; then
        SCRIPT_FILE="$0"
        echo -n "Удаляю файл скрипта $SCRIPT_FILE... "
        rm -f "$SCRIPT_FILE"
        print_success "✓ Удалено"
    fi
    
    exit 0
}

# Сохранение конфигурации
save_config() {
    local repo_url="$1"
    echo "REPO_URL=$repo_url" > "$CONFIG_FILE"
    echo "WORK_DIR=$WORK_DIR" >> "$CONFIG_FILE"
    echo "LAST_UPDATED=$(date)" >> "$CONFIG_FILE"
    print_success "✓ Конфигурация сохранена"
}

# Загрузка конфигурации
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# Функция проверки и установки зависимостей
install_dependencies() {
    echo -e "${YELLOW}[0/4] Проверка зависимостей...${NC}"
    
    # Проверка Docker
    if ! command -v docker &> /dev/null; then
        print_warning "Docker не установлен. Устанавливаю..."
        
        # Определение дистрибутива
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            sudo curl -fsSL https://get.docker.com | sh
        elif [ -f /etc/redhat-release ]; then
            # RHEL/CentOS/Fedora
            yum install -y docker
        elif [ -f /etc/arch-release ]; then
            # Arch Linux
            pacman -S docker --noconfirm
        else
            print_error "Не удалось определить дистрибутив для установки Docker"
            echo "Установите Docker вручную:"
            echo "- Debian/Ubuntu: sudo curl -fsSL https://get.docker.com | sh"
            echo "- CentOS/RHEL: sudo yum install docker"
            echo "- Arch: sudo pacman -S docker"
            exit 1
        fi
        
        # Запуск docker
        systemctl start docker
        systemctl enable docker
        print_success "✓ Docker установлен и запущен"
    else
        echo "✓ Docker уже установлен"
    fi
    
    # Проверка git
    if ! command -v git &> /dev/null; then
        print_warning "Git не установлен. Устанавливаю..."
        
        if [ -f /etc/debian_version ]; then
            apt update
            apt install git -y
        elif [ -f /etc/redhat-release ]; then
            yum install -y git
        elif [ -f /etc/arch-release ]; then
            pacman -S git --noconfirm
        else
            print_error "Не удалось определить дистрибутив для установки Git"
            echo "Установите Git вручную:"
            echo "- Debian/Ubuntu: sudo apt install git"
            echo "- CentOS/RHEL: sudo yum install git"
            echo "- Arch: sudo pacman -S git"
            exit 1
        fi
        print_success "✓ Git установлен"
    else
        echo "✓ Git уже установлен"
    fi
    
    # Проверка Golang (альтернативный вариант, если не использовать Docker)
    if ! command -v go &> /dev/null; then
        print_warning "Golang не установлен. Устанавливаю..."
        
        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y golang
        elif [ -f /etc/redhat-release ]; then
            yum install -y golang
        elif [ -f /etc/arch-release ]; then
            pacman -S go --noconfirm
        else
            print_info "Golang будет использоваться через Docker контейнер"
        fi
        print_success "✓ Golang установлен"
    else
        echo "✓ Golang уже установлен"
    fi
}

# Функция пересоздания dlc.dat
recreate_dlc() {
    local repo_url="$1"
    
    echo -e "${YELLOW}[1/1] Пересоздаем файл dlc.dat...${NC}"
    print_info "Используем репозиторий: $repo_url"
    
    # Проверка существования директории
    if [ ! -d "$WORK_DIR" ]; then
        print_error "Директория $WORK_DIR не существует"
        return 1
    fi
    
    # Переход в директорию
    cd "$WORK_DIR" || {
        print_error "Не удалось перейти в директорию $WORK_DIR"
        return 1
    }
    
    # Обновление репозитория (если это git репозиторий)
    if [ -d ".git" ]; then
        print_info "Обновляем репозиторий..."
        git pull
        if [ $? -eq 0 ]; then
            print_success "✓ Репозиторий обновлен"
        else
            print_warning "Не удалось обновить репозиторий, используем текущую версию"
        fi
    fi
    
    # Запуск генерации файла
    print_info "Запускаем генерацию через Docker...(может занять до двух минут)"
    print_info "Текущая директория: $(pwd)"
    print_info "Используем образ: golang:1.24-alpine"
    
    print_info "Скачиваем зависимости (с кешированием)..."

docker run --rm \
  -e GOPROXY=direct \
  -e GOSUMDB=off \
  -v dlcgen-gomod-cache:/go/pkg/mod \
  -v "$(pwd):/app" \
  -w /app \
  golang:1.24-alpine \
  go mod download

if [ $? -ne 0 ]; then
    print_error "✗ Ошибка при загрузке зависимостей"
    return 1
fi

print_info "Запускаем генерацию через Docker..."

docker run --rm \
  -e GOPROXY=direct \
  -e GOSUMDB=off \
  -v dlcgen-gomod-cache:/go/pkg/mod \
  -v "$(pwd):/app" \
  -w /app \
  golang:1.24-alpine \
  go run main.go

    
    if [ $? -eq 0 ]; then
        print_success "✓ Файл dlc.dat успешно пересоздан!"
        print_info "Результаты в директории: $WORK_DIR"
        return 0
    else
        print_error "✗ Ошибка при выполнении"
        print_info "Возможные причины:"
        echo "  1. В репозитории нет файла main.go"
        echo "  2. Ошибка в коде main.go"
        echo "  3. Проблемы с Docker"
        return 1
    fi
}

# Функция полной установки
full_installation() {
    local repo_url="$1"
    
    # Проверка и удаление старой директории
    echo -e "${YELLOW}[1/4] Проверяем наличие директории $WORK_DIR...${NC}"
    if [ -d "$WORK_DIR" ]; then
        print_warning "Директория $WORK_DIR уже существует"
        read -p "Удалить существующую директорию? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Удаляем старую директорию..."
            rm -rf "$WORK_DIR"
            print_success "✓ Директория удалена: $WORK_DIR"
        else
            print_info "Продолжаем в существующей директории"
        fi
    else
        echo "✓ Директория не существует, создаём новую"
    fi
    
    # Клонирование репозитория
    echo -e "${YELLOW}[2/4] Клонируем репозиторий...${NC}"
    print_info "Клонируем: $repo_url"
    git clone "$repo_url" "$WORK_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "✓ Репозиторий успешно клонирован"
    else
        print_error "✗ Ошибка при клонировании репозитория"
        print_info "Проверьте:"
        echo "  1. Корректность URL"
        echo "  2. Наличие доступа к репозиторию"
        echo "  3. Наличие прав на запись в /root"
        exit 1
    fi
    
    # Сохранение конфигурации
    save_config "$repo_url"
    
    # Запуск генерации файла
    echo -e "${YELLOW}[3/4] Запускаем генерацию через Docker...(может занять до двух минут)${NC}"
    print_info "Текущая директория: $(pwd)"
    print_info "Используем образ: golang:1.24-alpine"
    
   print_info "Скачиваем зависимости (с кешированием)..."

docker run --rm \
  -e GOPROXY=direct \
  -e GOSUMDB=off \
  -v dlcgen-gomod-cache:/go/pkg/mod \
  -v "$(pwd):/app" \
  -w /app \
  golang:1.24-alpine \
  go mod download

if [ $? -ne 0 ]; then
    print_error "✗ Ошибка при загрузке зависимостей"
    exit 1
fi

print_info "Запускаем генерацию через Docker..."

docker run --rm \
  -e GOPROXY=direct \
  -e GOSUMDB=off \
  -v dlcgen-gomod-cache:/go/pkg/mod \
  -v "$(pwd):/app" \
  -w /app \
  golang:1.24-alpine \
  go run main.go

    
    if [ $? -eq 0 ]; then
        print_success "✓ Файл успешно создан!"
        echo -e "${GREEN}=== Обновление завершено ===${NC}"
        print_info "Результаты в директории: $WORK_DIR"
    else
        print_error "✗ Ошибка при выполнении"
        print_info "Возможные причины:"
        echo "  1. В репозитории нет файла main.go"
        echo "  2. Ошибка в коде main.go"
        echo "  3. Проблемы с Docker"
        exit 1
    fi
}

# Главное меню
echo -e "${GREEN}=== Запуск dlcgen ===${NC}"

# Проверяем, установлен ли скрипт в PATH
if command -v dlcgen &> /dev/null; then
    print_info "✓ Скрипт уже установлен в PATH. Используйте команду: dlcgen"
    print_info "Для переустановки удалите текущую версию: sudo rm /usr/local/bin/dlcgen"
    echo ""
fi

# Главное меню действий
echo ""
print_info "Выберите действие:"
echo "  1) Начать работу со скриптом"
echo "  2) Установить/переустановить в системный PATH"
echo "  3) Удалить скрипт и все файлы (самоочистка)"
echo "  4) Выйти"

read -p "Ваш выбор (1-4): " main_choice

case $main_choice in
    2)
        install_to_path_simple
        exit 0
        ;;
    3)
        self_cleanup
        exit 0
        ;;
    4)
        print_info "Выход..."
        exit 0
        ;;
    *)
        # Продолжаем обычную работу
        ;;
esac

# Проверяем, есть ли сохраненная конфигурация
if load_config; then
    print_info "Найдена сохраненная конфигурация:"
    echo "  Репозиторий: $REPO_URL"
    echo "  Директория: $WORK_DIR"
    echo "  Последнее обновление: $LAST_UPDATED"
    
    echo ""
    print_info "Выберите действие:"
    echo "  1) Пересоздать файл dlc.dat (использовать сохраненную ссылку)"
    echo "  2) Пересоздать файл dlc.dat (ввести новую ссылку)"
    echo "  3) Полная переустановка (удалить всё и начать заново)"
    echo "  4) Вернуться в главное меню"
    
    read -p "Ваш выбор (1-4): " choice
    
    case $choice in
        1)
            print_info "Используем сохраненную ссылку: $REPO_URL"
            install_dependencies
            recreate_dlc "$REPO_URL"
            ;;
        2)
            read -p "Введите новую ссылку на репозиторий Git: " new_repo_url
            if [ -z "$new_repo_url" ]; then
                print_error "Не введена ссылка на репозиторий"
                exit 1
            fi
            install_dependencies
            recreate_dlc "$new_repo_url"
            save_config "$new_repo_url"
            ;;
        3)
            read -p "Введите ссылку на репозиторий Git (оставьте пустым для использования сохраненной [$REPO_URL]): " new_repo_url
            if [ -z "$new_repo_url" ]; then
                new_repo_url="$REPO_URL"
                print_info "Используем сохраненную ссылку: $new_repo_url"
            fi
            install_dependencies
            full_installation "$new_repo_url"
            ;;
        4)
            # Возвращаемся к началу скрипта
            exec bash -c "$(wget -qO- https://raw.githubusercontent.com/makdren/geosite-generator/main/dlcgen.sh)"
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
else
    # Нет сохраненной конфигурации - полная установка
    echo -e "${YELLOW}[2/4] Запрос ссылки на репозиторий${NC}"
    echo "Пример: https://github.com/user/repository.git"
    read -p "Введите ссылку на репозиторий Git: " repo_url
    
    # Проверка ввода
    if [ -z "$repo_url" ]; then
        print_error "✗ Не введена ссылка на репозиторий"
        exit 1
    fi
    
    install_dependencies
    full_installation "$repo_url"
fi
