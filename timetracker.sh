#!/bin/bash

# Script para executar o TimeTracker em background
# Este script permite que a aplicação continue rodando mesmo após fechar o terminal

APP_NAME="TimeTracker"
BUILD_PATH=".build/release/TimeTracker"
PID_FILE="/tmp/timetracker.pid"

# Função para verificar se a aplicação está rodando
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Função para iniciar a aplicação
start() {
    if is_running; then
        echo "❌ $APP_NAME já está rodando (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    echo "🚀 Iniciando $APP_NAME..."
    
    # Compilar se necessário
    if [ ! -f "$BUILD_PATH" ] || [ "Sources/" -nt "$BUILD_PATH" ]; then
        echo "🔨 Compilando aplicação..."
        swift build -c release
        if [ $? -ne 0 ]; then
            echo "❌ Erro na compilação!"
            exit 1
        fi
    fi
    
    # Executar em background
    nohup "$BUILD_PATH" > /dev/null 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    
    # Aguardar um pouco para verificar se iniciou corretamente
    sleep 2
    
    if is_running; then
        echo "✅ $APP_NAME iniciado com sucesso (PID: $PID)"
        echo "📱 Verifique a barra de menu do macOS"
    else
        echo "❌ Falha ao iniciar $APP_NAME"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Função para parar a aplicação
stop() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "🛑 Parando $APP_NAME (PID: $PID)..."
        kill $PID
        sleep 2
        
        if is_running; then
            echo "⚠️  Forçando parada..."
            kill -9 $PID
            sleep 1
        fi
        
        rm -f "$PID_FILE"
        echo "✅ $APP_NAME parado"
    else
        echo "❌ $APP_NAME não está rodando"
    fi
}

# Função para verificar status
status() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "✅ $APP_NAME está rodando (PID: $PID)"
    else
        echo "❌ $APP_NAME não está rodando"
    fi
}

# Função para reiniciar
restart() {
    stop
    sleep 1
    start
}

# Função para mostrar ajuda
help() {
    echo "📋 Uso: $0 {start|stop|restart|status|help}"
    echo ""
    echo "Comandos:"
    echo "  start   - Inicia o TimeTracker em background"
    echo "  stop    - Para o TimeTracker"
    echo "  restart - Reinicia o TimeTracker"
    echo "  status  - Mostra o status atual"
    echo "  help    - Mostra esta ajuda"
}

# Processar argumentos
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    help|--help|-h)
        help
        ;;
    *)
        echo "❌ Comando inválido: $1"
        echo ""
        help
        exit 1
        ;;
esac

exit 0
