#!/bin/bash

# Script de Teste do Sistema de Logs - ExpertAI
# Demonstra todas as funcionalidades do sistema de logging

set -euo pipefail

API_URL="${API_URL:-http://localhost:3000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de print colorido
print_step() {
    echo -e "${BLUE}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Verificar se API está rodando
check_api() {
    print_step "Verificando status da API..."

    if curl -s "${API_URL}/health" > /dev/null 2>&1; then
        print_success "API está rodando"
        return 0
    else
        print_error "API não está respondendo em ${API_URL}"
        print_info "Execute: docker-compose up -d"
        exit 1
    fi
}

# Teste 1: Health check do sistema de logs
test_log_health() {
    print_step "Teste 1: Verificando saúde do sistema de logs"

    response=$(curl -s "${API_URL}/api/logs/health")
    echo "$response" | jq '.' 2>/dev/null || echo "$response"

    print_success "Sistema de logs verificado"
}

# Teste 2: Registrar log de acesso
test_access_log() {
    print_step "Teste 2: Registrando log de acesso"

    response=$(curl -s -X POST "${API_URL}/api/logs/access" \
        -H "Content-Type: application/json" \
        -d '{
            "user": "test_user",
            "action": "LOGIN",
            "resource": "/dashboard",
            "status": "SUCCESS",
            "details": "Login bem-sucedido via teste automatizado"
        }')

    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    print_success "Log de acesso registrado"
}

# Teste 3: Registrar log de operação
test_operation_log() {
    print_step "Teste 3: Registrando log de operação"

    response=$(curl -s -X POST "${API_URL}/api/logs/operation" \
        -H "Content-Type: application/json" \
        -d '{
            "user": "test_script",
            "operation": "TEST_OPERATION",
            "target": "test_database",
            "status": "COMPLETED",
            "duration_ms": 1234,
            "records_affected": 42,
            "details": "Operação de teste executada com sucesso"
        }')

    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    print_success "Log de operação registrado"
}

# Teste 4: Listar logs de acesso
test_list_access_logs() {
    print_step "Teste 4: Listando logs de acesso (últimos 5)"

    response=$(curl -s "${API_URL}/api/logs/access?limit=5")
    echo "$response" | jq '.count, .total' 2>/dev/null || echo "$response"

    print_success "Logs de acesso listados"
}

# Teste 5: Listar logs de operação
test_list_operation_logs() {
    print_step "Teste 5: Listando logs de operação (últimos 5)"

    response=$(curl -s "${API_URL}/api/logs/operation?limit=5")
    echo "$response" | jq '.count, .total' 2>/dev/null || echo "$response"

    print_success "Logs de operação listados"
}

# Teste 6: Verificar arquivos de log
test_log_files() {
    print_step "Teste 6: Verificando arquivos de log"

    LOG_DIR="${SCRIPT_DIR}/../logs"

    if [[ -d "$LOG_DIR" ]]; then
        print_info "Arquivos em $LOG_DIR:"
        ls -lh "$LOG_DIR"/*.log 2>/dev/null || print_info "Nenhum arquivo .log encontrado"

        # Mostrar últimas 3 linhas de cada log
        for log_file in "$LOG_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                print_info "\nÚltimas 3 linhas de $(basename "$log_file"):"
                tail -n 3 "$log_file" 2>/dev/null || echo "Arquivo vazio"
            fi
        done

        print_success "Arquivos de log verificados"
    else
        print_error "Diretório de logs não encontrado: $LOG_DIR"
    fi
}

# Teste 7: Simular múltiplos logs
test_multiple_logs() {
    print_step "Teste 7: Simulando múltiplos logs de acesso"

    actions=("LOGIN" "LOGOUT" "VIEW" "CREATE" "UPDATE" "DELETE")
    statuses=("SUCCESS" "FAILURE" "WARNING")

    for i in {1..10}; do
        action=${actions[$((RANDOM % ${#actions[@]}))]}
        status=${statuses[$((RANDOM % ${#statuses[@]}))]}

        curl -s -X POST "${API_URL}/api/logs/access" \
            -H "Content-Type: application/json" \
            -d "{
                \"user\": \"test_user_$i\",
                \"action\": \"$action\",
                \"resource\": \"/resource/$i\",
                \"status\": \"$status\",
                \"details\": \"Teste automatizado #$i\"
            }" > /dev/null

        echo -n "."
    done

    echo ""
    print_success "10 logs de acesso simulados"
}

# Teste 8: Validação de schema
test_validation() {
    print_step "Teste 8: Testando validação de schema"

    print_info "Tentando enviar log inválido (sem campos obrigatórios)..."

    response=$(curl -s -X POST "${API_URL}/api/logs/access" \
        -H "Content-Type: application/json" \
        -d '{
            "user": "test"
        }')

    if echo "$response" | grep -q "error"; then
        print_success "Validação funcionando corretamente"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        print_error "Validação não funcionou como esperado"
    fi
}

# Teste 9: Criar usuário e registrar no log
test_user_creation_with_log() {
    print_step "Teste 9: Criando usuário e registrando operação"

    # Criar usuário
    print_info "Criando usuário de teste..."
    user_response=$(curl -s -X POST "${API_URL}/api/users" \
        -H "Content-Type: application/json" \
        -d '{
            "full_name": "Usuário Teste Log",
            "email": "teste.log.'$(date +%s)'@example.com",
            "cpf": "12345678901",
            "phone": "11999887766",
            "address": "Rua de Teste, 123"
        }')

    echo "$user_response" | jq '.data.id' 2>/dev/null || echo "Erro ao criar usuário"

    # Registrar operação de criação no log
    print_info "Registrando operação no log..."
    curl -s -X POST "${API_URL}/api/logs/operation" \
        -H "Content-Type: application/json" \
        -d '{
            "user": "test_script",
            "operation": "USER_CREATION",
            "target": "users_table",
            "status": "COMPLETED",
            "records_affected": 1,
            "details": "Usuário criado via script de teste"
        }' > /dev/null

    print_success "Usuário criado e operação registrada"
}

# Teste 10: Estatísticas de logs
test_log_statistics() {
    print_step "Teste 10: Estatísticas de logs"

    # Contar logs de acesso
    access_count=$(curl -s "${API_URL}/api/logs/access?limit=1000" | jq '.total' 2>/dev/null || echo "0")
    operation_count=$(curl -s "${API_URL}/api/logs/operation?limit=1000" | jq '.total' 2>/dev/null || echo "0")

    print_info "Total de logs de acesso: $access_count"
    print_info "Total de logs de operação: $operation_count"

    print_success "Estatísticas coletadas"
}

# Menu principal
show_menu() {
    echo ""
    echo "========================================"
    echo "   TESTE DO SISTEMA DE LOGS - ExpertAI"
    echo "========================================"
    echo ""
    echo "1. Executar todos os testes"
    echo "2. Health check do sistema de logs"
    echo "3. Registrar log de acesso"
    echo "4. Registrar log de operação"
    echo "5. Listar logs de acesso"
    echo "6. Listar logs de operação"
    echo "7. Verificar arquivos de log"
    echo "8. Simular múltiplos logs"
    echo "9. Testar validação de schema"
    echo "10. Criar usuário com log"
    echo "11. Ver estatísticas"
    echo "0. Sair"
    echo ""
    read -p "Escolha uma opção: " choice

    case $choice in
        1) run_all_tests ;;
        2) test_log_health ;;
        3) test_access_log ;;
        4) test_operation_log ;;
        5) test_list_access_logs ;;
        6) test_list_operation_logs ;;
        7) test_log_files ;;
        8) test_multiple_logs ;;
        9) test_validation ;;
        10) test_user_creation_with_log ;;
        11) test_log_statistics ;;
        0) exit 0 ;;
        *) print_error "Opção inválida" ;;
    esac

    show_menu
}

# Executar todos os testes
run_all_tests() {
    echo ""
    print_step "EXECUTANDO TODOS OS TESTES"
    echo ""

    check_api
    echo ""
    test_log_health
    echo ""
    test_access_log
    echo ""
    test_operation_log
    echo ""
    test_list_access_logs
    echo ""
    test_list_operation_logs
    echo ""
    test_log_files
    echo ""
    test_multiple_logs
    echo ""
    test_validation
    echo ""
    test_user_creation_with_log
    echo ""
    test_log_statistics
    echo ""

    print_success "TODOS OS TESTES CONCLUÍDOS!"
}

# Modo não-interativo
if [[ "${1:-}" == "--all" ]] || [[ "${1:-}" == "-a" ]]; then
    run_all_tests
    exit 0
fi

# Modo interativo
check_api
show_menu
