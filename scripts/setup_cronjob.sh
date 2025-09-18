#!/bin/bash

# Script para configurar cronjob de anonimização
# ExpertAI - Sistema de Anonimização PII

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANONYMIZE_SCRIPT="$SCRIPT_DIR/anonymize_pii.sh"

echo "=== Configurador de Cronjob - ExpertAI ==="
echo ""

# Verificar se script de anonimização existe
if [[ ! -f "$ANONYMIZE_SCRIPT" ]]; then
    echo "❌ Erro: Script de anonimização não encontrado: $ANONYMIZE_SCRIPT"
    exit 1
fi

# Verificar se script é executável
if [[ ! -x "$ANONYMIZE_SCRIPT" ]]; then
    echo "⚠️ Tornando script de anonimização executável..."
    chmod +x "$ANONYMIZE_SCRIPT"
fi

echo "✅ Script de anonimização encontrado: $ANONYMIZE_SCRIPT"
echo ""

# Opções de cronograma
echo "Escolha a frequência de execução da anonimização:"
echo "1) Diariamente às 02:00"
echo "2) Semanalmente (domingo às 02:00)"
echo "3) Mensalmente (dia 1 às 02:00)"
echo "4) A cada 6 horas"
echo "5) Personalizado"
echo ""

read -p "Digite sua escolha (1-5): " choice

case $choice in
    1)
        cron_schedule="0 2 * * *"
        description="Diariamente às 02:00"
        ;;
    2)
        cron_schedule="0 2 * * 0"
        description="Semanalmente (domingo às 02:00)"
        ;;
    3)
        cron_schedule="0 2 1 * *"
        description="Mensalmente (dia 1 às 02:00)"
        ;;
    4)
        cron_schedule="0 */6 * * *"
        description="A cada 6 horas"
        ;;
    5)
        echo ""
        echo "Formato do cron: minuto hora dia mês dia_semana"
        echo "Exemplos:"
        echo "  '0 2 * * *'     - Diariamente às 02:00"
        echo "  '30 14 * * 1'   - Segundas-feiras às 14:30"
        echo "  '0 */4 * * *'   - A cada 4 horas"
        echo ""
        read -p "Digite o cronograma personalizado: " cron_schedule
        description="Personalizado: $cron_schedule"
        ;;
    *)
        echo "❌ Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "📅 Cronograma selecionado: $description"
echo "📍 Cron expression: $cron_schedule"
echo ""

# Verificar crontab atual
echo "🔍 Verificando crontab atual..."
current_crontab=$(crontab -l 2>/dev/null || echo "")

# Verificar se já existe um cronjob para este script
if echo "$current_crontab" | grep -q "$ANONYMIZE_SCRIPT"; then
    echo "⚠️  Já existe um cronjob para este script."
    read -p "Deseja substituir? (s/N): " replace
    
    if [[ $(echo "$replace" | tr '[:upper:]' '[:lower:]') != "s" && $(echo "$replace" | tr '[:upper:]' '[:lower:]') != "sim" ]]; then
        echo "❌ Operação cancelada."
        exit 0
    fi
    
    # Remover linha existente
    echo "🗑️  Removendo cronjob existente..."
    current_crontab=$(echo "$current_crontab" | grep -v "$ANONYMIZE_SCRIPT")
fi

# Adicionar novo cronjob
new_crontab="$current_crontab
# ExpertAI - Anonimização PII ($description)
$cron_schedule $ANONYMIZE_SCRIPT >> $SCRIPT_DIR/../logs/cron.log 2>&1"

# Instalar novo crontab
echo "📝 Instalando novo cronjob..."
echo "$new_crontab" | crontab -

echo ""
echo "✅ Cronjob configurado com sucesso!"
echo ""
echo "📋 Resumo da configuração:"
echo "   Cronograma: $description"
echo "   Script: $ANONYMIZE_SCRIPT"
echo "   Log: $SCRIPT_DIR/../logs/cron.log"
echo ""
echo "🔧 Comandos úteis:"
echo "   Ver cronjobs: crontab -l"
echo "   Editar cronjobs: crontab -e"
echo "   Remover todos os cronjobs: crontab -r"
echo "   Ver logs: tail -f $SCRIPT_DIR/../logs/cron.log"
echo ""
echo "💡 Dica: Execute '$ANONYMIZE_SCRIPT' manualmente para testar antes da automação."