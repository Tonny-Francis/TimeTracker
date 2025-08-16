#!/bin/bash

# Script simplificado para build rápido
# Uso: ./quick_build.sh [versão]

VERSION=${1:-"1.0.0"}

echo "🚀 Build rápido do TimeTracker v${VERSION}"

# Limpar e compilar
echo "🔨 Compilando..."
swift build --configuration release

echo "✅ Build concluído!"
echo "📍 Para criar DMG: ./build_dmg.sh"
echo "📍 Para executar: ./.build/release/TimeTracker"
