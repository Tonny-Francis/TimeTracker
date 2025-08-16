#!/bin/bash

# Script para criar um DMG do TimeTracker
# Este script compila a aplicação e cria um instalador DMG

set -e

# Configurações
APP_NAME="TimeTracker"
APP_VERSION="1.0.0"
BUNDLE_ID="com.tonysousa.timetracker"
DMG_NAME="${APP_NAME}-${APP_VERSION}"
BUILD_DIR=".build"
RELEASE_DIR="release"
APP_DIR="${RELEASE_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🚀 Iniciando build do ${APP_NAME} v${APP_VERSION}"

# Limpar builds anteriores
echo "🧹 Limpando builds anteriores..."
rm -rf "${BUILD_DIR}"
rm -rf "${RELEASE_DIR}"
rm -f "${DMG_NAME}.dmg"

# Criar estrutura do .app bundle
echo "📁 Criando estrutura do app bundle..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compilar em modo release
echo "🔨 Compilando aplicação em modo release..."
swift build --configuration release

# Copiar executável
echo "📋 Copiando executável..."
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"

# Criar Info.plist
echo "📄 Criando Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>TimeTracker</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Criar ícone simples (texto)
echo "🎨 Criando ícone..."
cat > "${RESOURCES_DIR}/icon.txt" << EOF
TimeTracker App Icon
Para adicionar um ícone real, substitua este arquivo por um arquivo .icns
EOF

# Tornar executável
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Criar DMG temporário
echo "💿 Criando DMG..."
TEMP_DMG="${DMG_NAME}_temp.dmg"
hdiutil create -size 50m -fs HFS+ -volname "${APP_NAME}" "${TEMP_DMG}"

# Montar DMG temporário
echo "📦 Montando DMG temporário..."
MOUNT_POINT="/Volumes/${APP_NAME}"
hdiutil attach "${TEMP_DMG}"

# Copiar aplicação para o DMG
echo "📋 Copiando aplicação para o DMG..."
cp -R "${APP_DIR}" "${MOUNT_POINT}/"

# Criar link para Applications
echo "🔗 Criando link para Applications..."
ln -s /Applications "${MOUNT_POINT}/Applications"

# Criar arquivo README no DMG
cat > "${MOUNT_POINT}/README.txt" << EOF
TimeTracker v${APP_VERSION}

INSTALAÇÃO:
1. Arraste TimeTracker.app para a pasta Applications
2. Abra o Launchpad ou vá para Applications
3. Execute TimeTracker
4. O ícone aparecerá na barra de menu

PRIMEIRO USO:
- Um assistente de configuração aparecerá na primeira execução
- Configure suas horas de trabalho diárias
- Defina seu saldo inicial de horas extras (se houver)

RECURSOS:
✅ Controle de tempo de trabalho
✅ Gerenciamento de horas extras
✅ Estatísticas diárias, semanais e mensais
✅ Interface na barra de menu
✅ Configurações editáveis

Para suporte: https://github.com/Tonny-Francis/TimeTracker
EOF

# Desmontar DMG temporário
echo "📤 Desmontando DMG temporário..."
hdiutil detach "${MOUNT_POINT}"

# Converter para DMG final comprimido
echo "🗜️ Comprimindo DMG final..."
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${DMG_NAME}.dmg"

# Limpar arquivos temporários
echo "🧹 Limpando arquivos temporários..."
rm "${TEMP_DMG}"

echo "✅ DMG criado com sucesso: ${DMG_NAME}.dmg"
echo ""
echo "📍 Para instalar:"
echo "   1. Abra o arquivo ${DMG_NAME}.dmg"
echo "   2. Arraste TimeTracker.app para Applications"
echo "   3. Execute a partir do Launchpad ou Applications"
echo ""
echo "📊 Informações do build:"
echo "   Nome: ${APP_NAME}"
echo "   Versão: ${APP_VERSION}"
echo "   Bundle ID: ${BUNDLE_ID}"
echo "   Tamanho do DMG: $(du -h "${DMG_NAME}.dmg" | cut -f1)"
