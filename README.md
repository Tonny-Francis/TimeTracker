# TimeTracker - Monitor de Tempo de Trabalho para macOS

Uma aplicação simples e leve para monitorar tempo de trabalho no macOS, que roda na barra de menu.

## Funcionalidades

- ✅ Iniciar e encerrar sessões de trabalho
- ✅ **Pausar e retomar trabalho** (para almoço, pausas, etc.)
- ✅ Exibir tempo da sessão atual na barra de menu
- ✅ Mostrar tempo de pausa atual na barra de menu
- ✅ Mostrar estatísticas de horas trabalhadas (dia/semana/mês)
- ✅ Calcular e exibir horas extras acumuladas
- ✅ Permitir uso de horas extras acumuladas
- ✅ Interface apenas na barra de menu (sem janelas)
- ✅ Armazenamento local com UserDefaults

## Requisitos

- macOS 13.0 ou superior
- Xcode Command Line Tools

## Como compilar e executar

1. Compile o projeto:
```bash
swift build -c release
```

2. Execute a aplicação:
```bash
./.build/release/TimeTracker
```

A aplicação aparecerá na barra de menu do macOS com o tempo atual da sessão ou "⏸️ Parado" quando não estiver trabalhando.

## Como Usar

### Opção 1: Script de Gerenciamento (Recomendado)

Use o script `timetracker.sh` para gerenciar a aplicação:

```bash
# Iniciar a aplicação em background
./timetracker.sh start

# Verificar status
./timetracker.sh status

# Parar a aplicação
./timetracker.sh stop

# Reiniciar a aplicação
./timetracker.sh restart
```

### Opção 2: Execução Manual

1. **Compilar o projeto:**
   ```bash
   swift build -c release
   ```

2. **Executar a aplicação:**
   ```bash
   .build/release/TimeTracker
   ```
   ⚠️ **Nota:** Com este método, a aplicação para se você fechar o terminal ou pressionar Ctrl+C.

### Usando a Aplicação

- 📱 A aplicação aparece como um ícone na barra de menu do macOS
- 🖱️ Clique no ícone para acessar o menu com todas as opções
- ⏹️ Ícone quadrado = parado
- ▶️ Ícone play = trabalhando  
- ⏸️ Ícone pausa = pausado

### Estados da Barra de Menu

- **Parado**: `⏹️` (ícone de stop)
- **Trabalhando**: `▶️` (ícone de play)
- **Em Pausa**: `⏸️` (ícone de pause)

*O tempo detalhado aparece quando você clica no ícone para abrir o menu.*

## Configuração

- **Jornada padrão**: 6 horas por dia
- **Dias úteis**: Segunda a sexta-feira
- **Cálculo de extras**: Horas trabalhadas acima da jornada esperada em dias úteis

## Armazenamento

Os dados são salvos automaticamente no UserDefaults do sistema, mantendo:
- Histórico de sessões de trabalho (incluindo tempo de pausas)
- Registro de uso de horas extras
- Estado da sessão atual (ativa, pausada ou parada)
- Tempo total de pausas por sessão

## Desenvolvimento

Para modificar a aplicação:

1. Edite os arquivos em `Sources/`
2. Recompile com `swift build -c release`
3. Execute novamente

### Estrutura do projeto

- `main.swift`: Configuração da aplicação e delegate
- `MenuBarController.swift`: Controle da interface da barra de menu
- `TimeTracker.swift`: Lógica principal e gerenciamento de dados
