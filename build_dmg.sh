#!/bin/bash
set -e

APP_NAME="Eshret-YT-Downloader"
SCHEME="YouTubeLoader"
PROJECT="YouTubeLoader.xcodeproj"
BUILD_DIR="build"
DMG_DIR="$BUILD_DIR/dmg"
VERSION=$(date +"%Y.%m.%d")

echo "=== Сборка $APP_NAME v$VERSION ==="
echo ""

# 1. Очистка
echo "Очистка..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 2. Сборка Release
echo "Компиляция (Release)..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/derived" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    2>&1 | tail -5

# Найти .app
APP_PATH=$(find "$BUILD_DIR/derived" -name "*.app" -path "*/Release/*" | head -1)

if [ -z "$APP_PATH" ]; then
    # Попробовать из архива
    APP_PATH="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$SCHEME.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Ошибка: .app не найден"
    echo "Пробую обычную сборку..."

    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/derived" \
        build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_ALLOWED=YES \
        DEVELOPMENT_TEAM="" \
        2>&1 | tail -3

    APP_PATH=$(find "$BUILD_DIR/derived" -name "*.app" -path "*/Release/*" | head -1)
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Ошибка: не удалось найти собранное приложение"
    exit 1
fi

echo "Приложение: $APP_PATH"

# 3. Подготовка DMG
echo ""
echo "Создание DMG..."
mkdir -p "$DMG_DIR"

# Копируем приложение
cp -R "$APP_PATH" "$DMG_DIR/$APP_NAME.app"

# Создаём симлинк на Applications
ln -sf /Applications "$DMG_DIR/Applications"

# Создаём README
cat > "$DMG_DIR/ПРОЧТИ МЕНЯ.txt" << 'EOF'
Eshret-YT-Downloader — YouTube Загрузчик от Эшрета

УСТАНОВКА:
1. Перетащите приложение в папку Applications
2. При первом запуске macOS может предупредить о неизвестном разработчике
   → Нажмите правой кнопкой → Открыть → Открыть
3. Следуйте инструкциям на экране

ТРЕБОВАНИЯ:
- macOS 13.0 (Ventura) или новее
- Один из браузеров: Chrome, Firefox или Brave
- Авторизация на YouTube в браузере

При первом запуске приложение предложит установить
yt-dlp и ffmpeg автоматически (если их нет).
EOF

# 4. Создаём DMG
DMG_FILE="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_FILE" \
    2>&1

echo ""
echo "================================================"
echo "  Готово!"
echo "  DMG: $DMG_FILE"
echo "  Размер: $(du -h "$DMG_FILE" | cut -f1)"
echo "================================================"
echo ""

# Открыть папку с DMG
open "$BUILD_DIR"
