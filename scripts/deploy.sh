#!/bin/bash

# Script de Deploy Automático - ExpertAI
# Configura o sistema completo em servidor Linux (Debian/Ubuntu)

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
APP_USER="expertai"
APP_DIR="/home/$APP_USER/expertai-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Função para logging colorido
log() {
    local level="$1"
    local message="$2"
    local color="$NC"
    
    case $level in
        "INFO") color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "DEBUG") color="$BLUE" ;;
    esac
    
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Verificar se está rodando como root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "ERROR" "Este script não deve ser executado como root"
        log "INFO" "Execute como usuário normal com privilégios sudo"
        exit 1
    fi
}

# Verificar sistema operacional
check_system() {
    log "INFO" "Verificando sistema operacional..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        log "INFO" "Sistema detectado: macOS (modo desenvolvimento)"
        log "WARN" "Executando em modo desenvolvimento - algumas funcionalidades podem ser limitadas"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
        log "INFO" "Sistema detectado: Debian/Ubuntu"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
        log "INFO" "Sistema detectado: RedHat/CentOS"
        log "WARN" "Sistema RedHat detectado - ajustes podem ser necessários"
    else
        log "ERROR" "Sistema operacional não suportado"
        exit 1
    fi
}

# Instalar dependências do sistema
install_dependencies() {
    log "INFO" "Verificando dependências..."

    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Verificando dependências do macOS..."

        # Verificar se Docker Desktop está instalado
        if ! command -v docker &> /dev/null; then
            log "ERROR" "Docker Desktop não encontrado. Instale Docker Desktop para macOS"
            log "INFO" "Download: https://www.docker.com/products/docker-desktop"
            exit 1
        fi

        # Verificar se docker-compose está disponível
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            log "ERROR" "docker-compose não encontrado"
            exit 1
        fi

        # Verificar sqlite3
        if ! command -v sqlite3 &> /dev/null; then
            log "WARN" "SQLite3 não encontrado, instalando via Homebrew..."
            if command -v brew &> /dev/null; then
                brew install sqlite3
            else
                log "ERROR" "Homebrew não encontrado. Instale SQLite3 manualmente"
                exit 1
            fi
        fi

        log "INFO" "Dependências do macOS verificadas"
    else
        log "INFO" "Atualizando repositórios e instalando dependências..."

        sudo apt update
        sudo apt install -y \
            docker.io \
            docker-compose \
            nginx \
            sqlite3 \
            cron \
            git \
            curl \
            unzip \
            htop \
            tree \
            fail2ban

        log "INFO" "Dependências instaladas com sucesso"
    fi
}

# Configurar Docker
setup_docker() {
    log "INFO" "Configurando Docker..."

    if [[ "$OS" == "macos" ]]; then
        # No macOS, apenas verificar se Docker está rodando
        if ! docker info &> /dev/null; then
            log "ERROR" "Docker não está rodando. Inicie o Docker Desktop"
            exit 1
        fi
        log "INFO" "Docker está rodando no macOS"
    else
        sudo systemctl enable docker
        sudo systemctl start docker

        # Adicionar usuário atual ao grupo docker
        sudo usermod -aG docker $USER

        log "INFO" "Docker configurado com sucesso"
    fi
}

# Criar usuário da aplicação
create_app_user() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: usando usuário atual $(whoami)"
        APP_USER=$(whoami)
        APP_DIR="$(pwd)"
        return
    fi

    log "INFO" "Configurando usuário da aplicação..."

    if ! id "$APP_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $APP_USER
        log "INFO" "Usuário $APP_USER criado"
    else
        log "INFO" "Usuário $APP_USER já existe"
    fi

    sudo usermod -aG docker $APP_USER
    log "INFO" "Usuário $APP_USER adicionado ao grupo docker"
}

# Configurar diretório da aplicação
setup_app_directory() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: usando diretório atual $APP_DIR"
        return
    fi

    log "INFO" "Configurando diretório da aplicação..."

    sudo mkdir -p $APP_DIR
    sudo chown -R $APP_USER:$APP_USER $APP_DIR

    log "INFO" "Diretório da aplicação configurado: $APP_DIR"
}

# Copiar arquivos da aplicação
copy_application_files() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: arquivos já estão no diretório atual"

        # Apenas garantir que scripts são executáveis
        chmod +x scripts/*.sh

        log "INFO" "Scripts tornados executáveis"
        return
    fi

    log "INFO" "Copiando arquivos da aplicação..."

    # Copiar todos os arquivos do projeto
    sudo cp -r "$SCRIPT_DIR/../"* $APP_DIR/
    sudo chown -R $APP_USER:$APP_USER $APP_DIR

    # Tornar scripts executáveis
    sudo chmod +x $APP_DIR/scripts/*.sh

    log "INFO" "Arquivos da aplicação copiados com sucesso"
}

# Configurar NGINX
setup_nginx() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: NGINX será executado via Docker container"
        return
    fi

    log "INFO" "Configurando NGINX..."

    # Backup da configuração original
    if [[ -f /etc/nginx/nginx.conf ]] && [[ ! -f /etc/nginx/nginx.conf.backup ]]; then
        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    fi
    
    # Copiar configuração personalizada
    sudo cp $APP_DIR/nginx/sites-available/expertai.conf /etc/nginx/sites-available/
    
    # Remover site padrão
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Habilitar site ExpertAI
    sudo ln -sf /etc/nginx/sites-available/expertai.conf /etc/nginx/sites-enabled/
    
    # Testar configuração
    if sudo nginx -t; then
        log "INFO" "Configuração NGINX válida"
        sudo systemctl enable nginx
        sudo systemctl restart nginx
    else
        log "ERROR" "Erro na configuração NGINX"
        exit 1
    fi
    
    log "INFO" "NGINX configurado com sucesso"
}

# Configurar firewall
setup_firewall() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: firewall não configurado (uso local)"
        return
    fi

    log "INFO" "Configurando firewall..."

    if command -v ufw &> /dev/null; then
        sudo ufw --force enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow http
        sudo ufw allow https

        log "INFO" "Firewall UFW configurado"
    else
        log "WARN" "UFW não encontrado - configure firewall manualmente"
    fi
}

# Configurar fail2ban
setup_fail2ban() {
    if [[ "$OS" == "macos" ]]; then
        log "INFO" "Modo macOS: fail2ban não configurado (uso local)"
        return
    fi

    log "INFO" "Configurando Fail2ban..."

    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban

    log "INFO" "Fail2ban configurado e iniciado"
}

# Iniciar aplicação
start_application() {
    log "INFO" "Iniciando aplicação..."
    
    # Mudar para usuário da aplicação e iniciar containers
    sudo -u $APP_USER bash -c "
        cd $APP_DIR
        mkdir -p database logs database/backups
        docker-compose up --build -d
    "
    
    log "INFO" "Aguardando inicialização da aplicação..."
    sleep 30
    
    # Verificar se aplicação está rodando
    if curl -s http://localhost/health > /dev/null; then
        log "INFO" "✅ Aplicação iniciada com sucesso!"
    else
        log "ERROR" "❌ Falha ao iniciar aplicação"
        sudo -u $APP_USER docker-compose -f $APP_DIR/docker-compose.yml logs
        exit 1
    fi
}

# Configurar cronjob
setup_cronjob() {
    log "INFO" "Configurando cronjob de anonimização..."
    
    # Configurar cronjob automaticamente (diariamente às 02:00)
    sudo -u $APP_USER bash -c "
        cd $APP_DIR
        (crontab -l 2>/dev/null | grep -v '$APP_DIR/scripts/anonymize_pii.sh' || true; echo '0 2 * * * $APP_DIR/scripts/anonymize_pii.sh >> $APP_DIR/logs/cron.log 2>&1') | crontab -
    "
    
    log "INFO" "Cronjob configurado para execução diária às 02:00"
}

# Executar testes
run_tests() {
    log "INFO" "Executando testes da aplicação..."
    
    # Teste de conectividade
    if curl -s http://localhost/ > /dev/null; then
        log "INFO" "✅ Teste de conectividade: OK"
    else
        log "ERROR" "❌ Teste de conectividade: FALHOU"
        return 1
    fi
    
    # Teste de health check
    if curl -s http://localhost/health | grep -q "OK"; then
        log "INFO" "✅ Teste de health check: OK"
    else
        log "ERROR" "❌ Teste de health check: FALHOU"
        return 1
    fi
    
    # Teste de criação de usuário
    response=$(curl -s -X POST http://localhost/api/users \
        -H "Content-Type: application/json" \
        -d '{"full_name": "Teste Deploy", "email": "teste@deploy.com"}' \
        -w "%{http_code}")
    
    if [[ $(echo "$response" | tail -c 4) == "201" ]]; then
        log "INFO" "✅ Teste de criação de usuário: OK"
    else
        log "WARN" "⚠️ Teste de criação de usuário: pode ter falhado"
    fi
    
    log "INFO" "Testes concluídos"
}

# Exibir informações finais
show_final_info() {
    log "INFO" "=== DEPLOY CONCLUÍDO COM SUCESSO ==="
    echo ""
    echo -e "${GREEN}🎉 ExpertAI foi instalado e configurado com sucesso!${NC}"
    echo ""
    echo "📍 Informações do sistema:"
    echo "   - Usuário da aplicação: $APP_USER"
    echo "   - Diretório: $APP_DIR"

    if [[ "$OS" == "macos" ]]; then
        echo "   - URL da API: http://localhost/"
        echo "   - Health check: http://localhost/health"
    else
        local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
        echo "   - URL da API: http://$server_ip/"
        echo "   - Health check: http://$server_ip/health"
    fi
    echo ""
    echo "🔧 Comandos úteis:"
    if [[ "$OS" == "macos" ]]; then
        echo "   docker-compose ps"
        echo "   docker-compose logs -f"
        echo "   tail -f logs/anonymization.log"
    else
        echo "   sudo -u $APP_USER docker-compose -f $APP_DIR/docker-compose.yml ps"
        echo "   sudo -u $APP_USER docker-compose -f $APP_DIR/docker-compose.yml logs -f"
        echo "   tail -f $APP_DIR/logs/anonymization.log"
    fi
    echo ""
    echo "📚 Documentação completa: $APP_DIR/README.md"
    echo ""
    echo -e "${YELLOW}⚠️ IMPORTANTE:${NC}"
    echo "1. Faça logout e login novamente para aplicar permissões Docker"
    echo "2. Configure HTTPS com certificado SSL em produção"
    echo "3. Revise as configurações de segurança conforme necessário"
    echo "4. Execute backup regular do banco de dados"
    echo ""
}

# Função principal
main() {
    log "INFO" "Iniciando deploy do ExpertAI..."
    
    check_root
    check_system
    install_dependencies
    setup_docker
    create_app_user
    setup_app_directory
    copy_application_files
    setup_nginx
    setup_firewall
    setup_fail2ban
    start_application
    setup_cronjob
    run_tests
    show_final_info
    
    log "INFO" "Deploy concluído com sucesso! 🚀"
}

# Tratamento de erros
trap 'log "ERROR" "Deploy falhou na linha $LINENO"; exit 1' ERR

# Executar função principal
main "$@"