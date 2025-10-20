#!/bin/bash

# Script de Configuração de Usuários Linux - ExpertAI
# Cria usuários dedicados para escrita de logs e execução de scripts de anonimização

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script deve ser executado como root (use sudo)"
   exit 1
fi

echo "=== Configuração de Usuários ExpertAI ==="
echo ""

# Configurações
LOG_USER="expertai_logger"
ANONYMIZE_USER="expertai_anonymizer"
PROJECT_DIR="/opt/ExpertAI"
LOG_DIR="${PROJECT_DIR}/logs"
DB_DIR="${PROJECT_DIR}/database"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"

# Criar grupo compartilhado
GROUP_NAME="expertai"

echo "📝 Criando grupo: $GROUP_NAME"
if ! getent group "$GROUP_NAME" >/dev/null 2>&1; then
    groupadd "$GROUP_NAME"
    echo "✅ Grupo $GROUP_NAME criado"
else
    echo "ℹ️  Grupo $GROUP_NAME já existe"
fi

# Criar usuário para logs
echo ""
echo "👤 Criando usuário: $LOG_USER"
if ! id "$LOG_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/bash -g "$GROUP_NAME" -c "ExpertAI Logger User" "$LOG_USER"
    echo "✅ Usuário $LOG_USER criado"
else
    echo "ℹ️  Usuário $LOG_USER já existe"
fi

# Criar usuário para anonimização
echo ""
echo "👤 Criando usuário: $ANONYMIZE_USER"
if ! id "$ANONYMIZE_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/bash -g "$GROUP_NAME" -c "ExpertAI Anonymizer User" "$ANONYMIZE_USER"
    echo "✅ Usuário $ANONYMIZE_USER criado"
else
    echo "ℹ️  Usuário $ANONYMIZE_USER já existe"
fi

# Configurar permissões de diretórios
echo ""
echo "🔐 Configurando permissões de diretórios..."

# Criar diretório de logs se não existir
mkdir -p "$LOG_DIR"
# Criar diretório /var/log com permissões para o grupo
mkdir -p /var/log

# Logs: escrita para grupo expertai
chown -R root:"$GROUP_NAME" "$LOG_DIR"
chmod 775 "$LOG_DIR"
chmod 664 "$LOG_DIR"/*.log 2>/dev/null || true

# Dar permissões ao grupo para escrever em /var/log
chown root:"$GROUP_NAME" /var/log
chmod 775 /var/log

echo "✅ Diretório de logs: $LOG_DIR (rwxrwxr-x)"

# Database: leitura/escrita para anonymize_user
if [[ -d "$DB_DIR" ]]; then
    chown -R "$ANONYMIZE_USER":"$GROUP_NAME" "$DB_DIR"
    chmod 775 "$DB_DIR"
    chmod 664 "$DB_DIR"/*.db 2>/dev/null || true
    echo "✅ Diretório de database: $DB_DIR (rwxrwxr-x)"
fi

# Scripts: execução para anonymize_user
if [[ -d "$SCRIPTS_DIR" ]]; then
    chown -R root:"$GROUP_NAME" "$SCRIPTS_DIR"
    chmod 755 "$SCRIPTS_DIR"
    chmod 750 "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
    echo "✅ Diretório de scripts: $SCRIPTS_DIR (rwxr-xr-x)"
fi

# Configurar sudo para permitir execução do script de anonimização
echo ""
echo "🔑 Configurando sudo para $ANONYMIZE_USER..."

SUDOERS_FILE="/etc/sudoers.d/expertai"
cat > "$SUDOERS_FILE" <<EOF
# ExpertAI - Permissões para usuários do sistema
# Criado em: $(date)

# Permitir usuário anonymizer executar script de anonimização sem senha
$ANONYMIZE_USER ALL=(root) NOPASSWD: ${SCRIPTS_DIR}/anonymize_pii.sh

# Permitir usuário anonymizer reiniciar docker-compose
$ANONYMIZE_USER ALL=(root) NOPASSWD: /usr/bin/docker-compose restart api

# Permitir usuário logger escrever em /var/log
$LOG_USER ALL=(root) NOPASSWD: /usr/bin/tee -a /var/log/xp_*.log
EOF

chmod 440 "$SUDOERS_FILE"
echo "✅ Configuração sudo criada: $SUDOERS_FILE"

# Verificar sintaxe do sudoers
if ! visudo -c -f "$SUDOERS_FILE"; then
    echo "❌ Erro na configuração do sudoers"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

# Adicionar usuário atual ao grupo (opcional)
CURRENT_USER="${SUDO_USER:-$USER}"
if [[ -n "$CURRENT_USER" ]] && [[ "$CURRENT_USER" != "root" ]]; then
    echo ""
    read -p "Adicionar usuário $CURRENT_USER ao grupo $GROUP_NAME? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        usermod -aG "$GROUP_NAME" "$CURRENT_USER"
        echo "✅ Usuário $CURRENT_USER adicionado ao grupo $GROUP_NAME"
        echo "⚠️  Faça logout e login novamente para aplicar as mudanças de grupo"
    fi
fi

# Criar arquivo de ambiente para os usuários
echo ""
echo "📄 Criando arquivo de ambiente..."

ENV_FILE="${SCRIPTS_DIR}/.env.users"
cat > "$ENV_FILE" <<EOF
# Variáveis de ambiente para usuários ExpertAI
# Criado em: $(date)

export PROJECT_DIR="${PROJECT_DIR}"
export LOG_DIR="${LOG_DIR}"
export DB_DIR="${DB_DIR}"
export SCRIPTS_DIR="${SCRIPTS_DIR}"
export API_URL="http://localhost:3000"
EOF

chmod 644 "$ENV_FILE"
echo "✅ Arquivo de ambiente criado: $ENV_FILE"

# Resumo final
echo ""
echo "=========================================="
echo "✅ Configuração concluída com sucesso!"
echo "=========================================="
echo ""
echo "📋 Resumo:"
echo "  - Grupo criado: $GROUP_NAME"
echo "  - Usuário de logs: $LOG_USER"
echo "  - Usuário de anonimização: $ANONYMIZE_USER"
echo ""
echo "📂 Diretórios configurados:"
echo "  - Logs: $LOG_DIR (grupo: $GROUP_NAME)"
echo "  - Database: $DB_DIR (owner: $ANONYMIZE_USER)"
echo "  - Scripts: $SCRIPTS_DIR (grupo: $GROUP_NAME)"
echo ""
echo "🔐 Permissões sudo configuradas em: $SUDOERS_FILE"
echo ""
echo "📝 Para testar:"
echo "  # Como usuário anonymizer"
echo "  sudo -u $ANONYMIZE_USER ${SCRIPTS_DIR}/anonymize_pii.sh"
echo ""
echo "  # Verificar permissões"
echo "  ls -la $LOG_DIR"
echo "  ls -la $DB_DIR"
echo ""
