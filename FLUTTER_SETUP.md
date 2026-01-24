# Настройка Flutter для терминала

## Вариант 1: Если Flutter установлен через VS Code

VS Code использует Flutter через расширение, но для терминала нужно добавить Flutter в PATH.

### Шаг 1: Найти путь к Flutter

Откройте VS Code и выполните:
1. Нажмите `Cmd+Shift+P`
2. Введите "Flutter: Locate SDK"
3. Скопируйте путь (например: `/Users/alex/flutter` или `/Users/alex/.flutter-sdk`)

### Шаг 2: Добавить в PATH

Откройте терминал и выполните:

```bash
# Откройте файл конфигурации
nano ~/.zshrc

# Добавьте в конец файла (замените путь на ваш):
export PATH="$PATH:/Users/alex/flutter/bin"

# Сохраните (Ctrl+O, Enter, Ctrl+X)

# Примените изменения
source ~/.zshrc
```

### Шаг 3: Проверка

```bash
flutter --version
flutter doctor
```

---

## Вариант 2: Установка Flutter через Homebrew (если не установлен)

```bash
# Установка Flutter
brew install --cask flutter

# Проверка
flutter doctor
```

---

## Вариант 3: Ручная установка Flutter

```bash
# Перейти в домашнюю директорию
cd ~

# Скачать Flutter
git clone https://github.com/flutter/flutter.git -b stable

# Добавить в PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Проверка
flutter doctor
```

---

## После установки: Создание нового проекта

```bash
# Перейти в нужную директорию
cd ~/Desktop

# Создать новый проект
flutter create my_new_app

# Перейти в проект
cd my_new_app

# Запустить
flutter run
```

---

## Настройка Android Studio (если нужно)

1. Откройте Android Studio
2. File → Settings → Plugins
3. Установите "Flutter" и "Dart" плагины
4. File → Settings → Languages & Frameworks → Flutter
5. Укажите путь к Flutter SDK

---

## Проверка установки

```bash
flutter doctor -v
```

Должны быть галочки для:
- ✅ Flutter
- ✅ Android toolchain (если разрабатываете для Android)
- ✅ VS Code (если используете)
