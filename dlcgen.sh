#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурационный файл
CONFIG_FILE="/root/dlcgen_config"
WORK_DIR="/root/dlcgen"

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
    
    docker run --rm -v "$(pwd):/app" -w /app golang:1.24-alpine go run main.go
    
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
    
    docker run --rm -v "$(pwd):/app" -w /app golang:1.24-alpine go run main.go
    
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
    echo "  4) Выйти"
    
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
            print_info "Выход..."
            exit 0
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