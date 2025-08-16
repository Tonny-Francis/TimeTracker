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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

# Criar ícone a partir do PNG
echo "🎨 Convertendo ícone PNG para ICNS..."
if [ -f "assets/icon.png" ]; then
    # Criar iconset temporário
    mkdir -p "${RESOURCES_DIR}/AppIcon.iconset"
    
    # Verificar se sips está disponível para conversão
    if command -v sips &> /dev/null; then
        # Gerar diferentes tamanhos para o iconset
        sips -z 16 16 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_16x16.png"
        sips -z 32 32 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_16x16@2x.png"
        sips -z 32 32 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_32x32.png"
        sips -z 64 64 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_32x32@2x.png"
        sips -z 128 128 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_128x128.png"
        sips -z 256 256 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_128x128@2x.png"
        sips -z 256 256 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_256x256.png"
        sips -z 512 512 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_256x256@2x.png"
        sips -z 512 512 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_512x512.png"
        sips -z 1024 1024 "assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.iconset/icon_512x512@2x.png"
        
        # Converter iconset para icns
        if command -v iconutil &> /dev/null; then
            iconutil -c icns "${RESOURCES_DIR}/AppIcon.iconset" -o "${RESOURCES_DIR}/AppIcon.icns"
            rm -rf "${RESOURCES_DIR}/AppIcon.iconset"
            echo "✅ Ícone ICNS criado com sucesso!"
        else
            echo "⚠️  iconutil não encontrado, usando PNG original"
            cp "assets/icon.png" "${RESOURCES_DIR}/AppIcon.png"
        fi
    else
        echo "⚠️  sips não encontrado, usando PNG original"
        cp "assets/icon.png" "${RESOURCES_DIR}/AppIcon.png"
    fi
else
    echo "⚠️  Arquivo assets/icon.png não encontrado, criando ícone padrão"
    cat > "${RESOURCES_DIR}/icon.txt" << EOF
TimeTracker App Icon
Para adicionar um ícone real, adicione um arquivo assets/icon.png
EOF
fi

# Tornar executável
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Criar DMG temporário
echo "💿 Criando DMG..."
TEMP_DMG="${DMG_NAME}_temp.dmg"
DMG_DIR="dmg_temp"

# Criar diretório temporário para o DMG
mkdir -p "${DMG_DIR}"

# Copiar aplicação para o diretório temporário
echo "📋 Preparando conteúdo do DMG..."
cp -R "${APP_DIR}" "${DMG_DIR}/"

# Criar link para Applications
echo "🔗 Criando link para Applications..."
ln -s /Applications "${DMG_DIR}/Applications"

# Criar arquivo README no diretório temporário
cat > "${DMG_DIR}/README.txt" << EOF
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

# Criar DMG a partir do diretório
echo "� Criando DMG a partir do diretório..."
hdiutil create -srcfolder "${DMG_DIR}" -volname "${APP_NAME}" "${TEMP_DMG}"

# Converter para DMG final comprimido
echo "🗜️ Comprimindo DMG final..."
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${DMG_NAME}.dmg"

# Limpar arquivos temporários
echo "🧹 Limpando arquivos temporários..."
rm "${TEMP_DMG}"
rm -rf "${DMG_DIR}"

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
