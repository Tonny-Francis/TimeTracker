#!/bin/bash

# Script de instalação do TimeTracker
# Este script copia o TimeTracker.app para /Applications

APP_NAME="TimeTracker"
SOURCE_APP="release/${APP_NAME}.app"
DEST_DIR="/Applications"

echo "🚀 Instalador do ${APP_NAME}"

# Verificar se o .app existe
if [ ! -d "${SOURCE_APP}" ]; then
    echo "❌ Erro: ${SOURCE_APP} não encontrado!"
    echo "   Execute './build_dmg.sh' primeiro para gerar a aplicação."
    exit 1
fi

# Verificar permissões de escrita em /Applications
if [ ! -w "${DEST_DIR}" ]; then
    echo "⚠️  Permissões necessárias para instalar em ${DEST_DIR}"
    echo "   Este script requer privilégios de administrador."
    sudo -v
    if [ $? -ne 0 ]; then
        echo "❌ Instalação cancelada."
        exit 1
    fi
    USE_SUDO="sudo"
else
    USE_SUDO=""
fi

# Remover versão existente se houver
if [ -d "${DEST_DIR}/${APP_NAME}.app" ]; then
    echo "🗑️  Removendo versão anterior..."
    ${USE_SUDO} rm -rf "${DEST_DIR}/${APP_NAME}.app"
fi

# Copiar nova versão
echo "📋 Instalando ${APP_NAME}.app em ${DEST_DIR}..."
${USE_SUDO} cp -R "${SOURCE_APP}" "${DEST_DIR}/"

# Verificar se a instalação foi bem-sucedida
if [ -d "${DEST_DIR}/${APP_NAME}.app" ]; then
    echo "✅ ${APP_NAME} instalado com sucesso!"
    echo ""
    echo "📍 Para executar:"
    echo "   • Abra o Launchpad"
    echo "   • Ou vá para Applications"
    echo "   • Execute ${APP_NAME}"
    echo "   • O ícone aparecerá na barra de menu"
    echo ""
    echo "🎉 Primeira execução:"
    echo "   • Um assistente de configuração aparecerá"
    echo "   • Configure suas horas de trabalho"
    echo "   • Defina seu saldo de horas extras"
else
    echo "❌ Erro na instalação!"
    exit 1
fi
