#!/bin/bash

# Script de Anonimização de Dados PII - ExpertAI
# Executa anonimização de dados sensíveis no banco SQLite
# Autor: ExpertAI Team
# Data: $(date +"%Y-%m-%d")

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="${SCRIPT_DIR}/../database/users.db"
LOG_FILE="${SCRIPT_DIR}/../logs/anonymization.log"
BACKUP_DIR="${SCRIPT_DIR}/../database/backups"
DATE_STAMP=$(date +"%Y%m%d_%H%M%S")

# Criar diretórios necessários
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$BACKUP_DIR"

# Função de logging
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Função para gerar CPF anonimizado
generate_fake_cpf() {
    printf "%03d.%03d.%03d-%02d" $((RANDOM % 900 + 100)) $((RANDOM % 900 + 100)) $((RANDOM % 900 + 100)) $((RANDOM % 90 + 10))
}

# Função para gerar RG anonimizado
generate_fake_rg() {
    printf "%d.%03d.%03d-%d" $((RANDOM % 90 + 10)) $((RANDOM % 900 + 100)) $((RANDOM % 900 + 100)) $((RANDOM % 9 + 1))
}

# Função para gerar telefone anonimizado
generate_fake_phone() {
    local area_code=$((RANDOM % 80 + 11))  # Códigos de área de 11 a 99
    local number=$((RANDOM % 900000000 + 900000000))  # 9 dígitos
    printf "%02d9%08d" $area_code $number
}

# Função para gerar nome anonimizado
generate_fake_name() {
    local first_names=("João" "Maria" "José" "Ana" "Pedro" "Carla" "Paulo" "Lucia" "Carlos" "Fernanda")
    local last_names=("Silva" "Santos" "Oliveira" "Souza" "Rodrigues" "Ferreira" "Alves" "Pereira" "Lima" "Gomes")
    
    local first_name=${first_names[$((RANDOM % ${#first_names[@]}))]}
    local last_name=${last_names[$((RANDOM % ${#last_names[@]}))]}
    
    echo "$first_name $last_name"
}

# Função para gerar endereço anonimizado
generate_fake_address() {
    local streets=("Rua das Flores" "Av. Principal" "Rua Central" "Av. Brasil" "Rua São José" "Rua da Paz" "Av. Paulista" "Rua América" "Av. Independência" "Rua Liberdade")
    local street=${streets[$((RANDOM % ${#streets[@]}))]}
    local number=$((RANDOM % 9999 + 1))
    
    echo "$street, $number"
}

# Verificar se o banco existe
check_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        log "ERROR" "Banco de dados não encontrado: $DB_PATH"
        exit 1
    fi
    
    if ! command -v sqlite3 &> /dev/null; then
        log "ERROR" "SQLite3 não está instalado"
        exit 1
    fi
    
    log "INFO" "Banco de dados encontrado e SQLite disponível"
}

# Criar backup antes da anonimização
create_backup() {
    local backup_file="$BACKUP_DIR/users_backup_$DATE_STAMP.db"
    
    log "INFO" "Criando backup do banco de dados..."
    
    if cp "$DB_PATH" "$backup_file"; then
        log "INFO" "Backup criado com sucesso: $backup_file"
        
        # Manter apenas os últimos 10 backups
        find "$BACKUP_DIR" -name "users_backup_*.db" -type f | sort -r | tail -n +11 | xargs rm -f
        log "INFO" "Backups antigos removidos (mantendo últimos 10)"
    else
        log "ERROR" "Falha ao criar backup"
        exit 1
    fi
}

# Contar registros antes da anonimização
count_records() {
    local count
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE full_name NOT LIKE 'ANONIMIZADO_%';")
    echo "$count"
}

# Executar anonimização
anonymize_data() {
    log "INFO" "Iniciando processo de anonimização..."
    
    local total_records
    total_records=$(count_records)
    
    if [[ $total_records -eq 0 ]]; then
        log "INFO" "Nenhum registro não-anonimizado encontrado"
        return 0
    fi
    
    log "INFO" "Encontrados $total_records registros para anonimizar"
    
    # Buscar IDs dos usuários não anonimizados
    local user_ids
    user_ids=$(sqlite3 "$DB_PATH" "SELECT id FROM users WHERE full_name NOT LIKE 'ANONIMIZADO_%';")
    
    local anonymized_count=0
    
    # Processar cada usuário
    while IFS= read -r user_id; do
        if [[ -n "$user_id" ]]; then
            local fake_name fake_cpf fake_rg fake_phone fake_address
            
            fake_name="ANONIMIZADO_$(generate_fake_name)"
            fake_cpf="$(generate_fake_cpf)"
            fake_rg="$(generate_fake_rg)"
            fake_phone="$(generate_fake_phone)"
            fake_address="$(generate_fake_address)"
            
            # Executar atualização
            sqlite3 "$DB_PATH" "
                UPDATE users 
                SET 
                    full_name = '$fake_name',
                    cpf = '$fake_cpf',
                    rg = '$fake_rg',
                    phone = '$fake_phone',
                    address = '$fake_address',
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = $user_id;
            "
            
            ((anonymized_count++))
            
            # Log a cada 10 registros processados
            if [[ $((anonymized_count % 10)) -eq 0 ]]; then
                log "INFO" "Processados $anonymized_count de $total_records registros"
            fi
        fi
    done <<< "$user_ids"
    
    log "INFO" "Anonimização concluída: $anonymized_count registros processados"
}

# Verificar integridade após anonimização
verify_anonymization() {
    log "INFO" "Verificando integridade da anonimização..."
    
    local non_anonymized
    non_anonymized=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE full_name NOT LIKE 'ANONIMIZADO_%';")
    
    local total_records
    total_records=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users;")
    
    if [[ $non_anonymized -eq 0 ]]; then
        log "INFO" "✅ Verificação OK: Todos os $total_records registros foram anonimizados"
    else
        log "WARNING" "⚠️ Ainda existem $non_anonymized registros não anonimizados de $total_records total"
    fi
    
    # Verificar se há dados duplicados
    local duplicated_cpf
    duplicated_cpf=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM (SELECT cpf FROM users GROUP BY cpf HAVING COUNT(*) > 1);")
    
    if [[ $duplicated_cpf -gt 0 ]]; then
        log "WARNING" "⚠️ Encontrados $duplicated_cpf CPFs duplicados"
    else
        log "INFO" "✅ Nenhum CPF duplicado encontrado"
    fi
}

# Reiniciar API para limpar cache SQLite
restart_api_if_needed() {
    log "INFO" "Reiniciando API para aplicar mudanças..."

    local project_dir="$(cd "$SCRIPT_DIR/.." && pwd)"

    if command -v docker-compose &> /dev/null; then
        if cd "$project_dir" && docker-compose restart api >/dev/null 2>&1; then
            log "INFO" "✅ API reiniciada com sucesso"
        else
            log "WARN" "⚠️ Não foi possível reiniciar a API automaticamente"
            log "INFO" "Execute manualmente: docker-compose restart api"
        fi
    else
        log "WARN" "⚠️ docker-compose não encontrado"
        log "INFO" "Reinicie a API manualmente para aplicar as mudanças"
    fi
}

# Limpeza de logs antigos
cleanup_logs() {
    log "INFO" "Limpando logs antigos..."
    
    # Manter logs dos últimos 30 dias
    find "$(dirname "$LOG_FILE")" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
    
    # Limitar tamanho do log atual (manter últimas 1000 linhas)
    if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
        tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    
    log "INFO" "Limpeza de logs concluída"
}

# Função principal
main() {
    log "INFO" "=== Iniciando processo de anonimização PII ==="
    log "INFO" "Banco de dados: $DB_PATH"
    log "INFO" "Data/Hora: $(date)"
    
    check_database
    create_backup
    anonymize_data
    verify_anonymization
    restart_api_if_needed
    cleanup_logs

    log "INFO" "=== Processo de anonimização concluído ==="
}

# Tratamento de sinais
trap 'log "ERROR" "Script interrompido pelo usuário"; exit 1' INT TERM

# Executar função principal
main "$@"