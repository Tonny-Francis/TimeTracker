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

## Como usar

1. **Iniciar trabalho**: Clique no ícone na barra de menu e selecione "Iniciar Trabalho"
2. **Pausar trabalho**: Durante uma sessão ativa, selecione "Pausar Trabalho" (para almoço, pausas, etc.)
3. **Retomar trabalho**: Quando em pausa, selecione "Retomar Trabalho"
4. **Parar trabalho**: Clique no ícone e selecione "Parar Trabalho"
5. **Ver estatísticas**: As estatísticas aparecem automaticamente no menu:
   - Hoje: tempo total e horas extras do dia
   - Semana: tempo total e horas extras da semana
   - Mês: tempo total e horas extras do mês
6. **Usar horas extras**: Quando há saldo disponível, aparece a opção "Usar 1h Extra"

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
