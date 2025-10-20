# 🚀 ExpertAI - Guia de Início Rápido

## 🎯 Requisitos Cumpridos ✅

✅ **25%** - Servidor Linux (Debian/Ubuntu) com Docker, NGINX e acesso à internet
✅ **25%** - SQLite em container Docker com volume externo compartilhado
✅ **25%** - API Node.js com endpoints para CRUD de usuários **+ Sistema de Logs (xp_access.log, xp_operation.log)**
✅ **25%** - Cronjob automático para anonimização de dados PII **+ Usuários Linux dedicados**
✅ **50%** - README.md completo com documentação e explicação dos recursos

### Para Servidor Linux (Ubuntu/Debian)

```bash
# 1. Fazer upload dos arquivos para o servidor
scp -r ExpertAI/ user@servidor:/opt/
ssh user@servidor

# 2. Entrar no diretório e executar deploy
cd /opt/ExpertAI
chmod +x scripts/*.sh
./scripts/deploy.sh

# 3. Configurar usuários Linux dedicados (IMPORTANTE!)
sudo ./scripts/setup_users.sh

# 4. Configurar cronjob de anonimização
./scripts/setup_cronjob.sh
```

### Para Desenvolvimento Local (macOS/Linux/Windows)

```bash
# 1. Entrar no diretório do projeto
cd ExpertAI

# 2. Iniciar sistema completo
docker-compose up --build -d

# 3. (Opcional) Configurar usuários Linux dedicados
sudo ./scripts/setup_users.sh

# 4. (Opcional) Configurar cronjob para desenvolvimento
chmod +x scripts/*.sh
./scripts/setup_cronjob.sh
```

**Acesso:**

- 🌐 API Principal: `http://localhost/` ou `http://SEU_IP/`
- 💚 Health Check: `http://localhost/health`
- 👥 Usuários: `http://localhost/api/users`
- 📝 Logs de Acesso: `http://localhost/api/logs/access`
- 📊 Logs de Operação: `http://localhost/api/logs/operation`
- 🔍 Status dos Logs: `http://localhost/api/logs/health`

### 1. ✅ Verificar se sistema está funcionando

```bash
curl http://localhost/health
# Resposta esperada: {"status":"OK","timestamp":"...","uptime":...}
```

### 2. ✅ Criar usuário de teste

```bash
curl -X POST http://localhost/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "João Silva",
    "email": "joao.silva@teste.com",
    "cpf": "12345678901",
    "rg": "123456789",
    "phone": "11999887766",
    "address": "Av. Paulista, 123"
  }'
```

### 3. ✅ Listar usuários cadastrados

```bash
curl http://localhost/api/users
# Mostra todos os usuários com paginação
```

### 4. ✅ Testar anonimização de PII

```bash
./scripts/anonymize_pii.sh
# Executa anonimização e mostra logs detalhados
```

### 5. ✅ Verificar dados anonimizados

```bash
curl http://localhost/api/users
# Usuários agora têm prefixo "ANONIMIZADO_" nos nomes
```

### 6. ✅ Verificar acesso à internet dos containers

```bash
docker exec expertai_api ping -c 3 google.com
docker exec expertai_database ping -c 3 google.com
# Ambos devem responder com sucesso
```

## 📊 Status Atual do Sistema

### Containers Ativos

```bash
docker ps
```

| Container         | Status | Porta | Função                    |
| ----------------- | ------ | ----- | ------------------------- |
| expertai_nginx    | ✅ UP  | 80    | Proxy reverso + SSL       |
| expertai_api      | ✅ UP  | 3000  | API REST Node.js          |
| expertai_database | ✅ UP  | -     | SQLite com volume externo |

### Banco de Dados

```bash
# Ver usuários no banco
docker exec expertai_database sqlite3 /data/users.db "SELECT COUNT(*) FROM users;"

# Ver estrutura da tabela
docker exec expertai_database sqlite3 /data/users.db ".schema users"

# Ver backups disponíveis
ls -la database/backups/
```

### Sistema de Anonimização

```bash
# Ver status do cronjob
crontab -l | grep anonymize

# Ver logs de anonimização
tail -f logs/anonymization.log

# Executar manualmente
./scripts/anonymize_pii.sh
```

## 🔧 Comandos Essenciais

### Gerenciamento de Containers

```bash
# Ver todos os containers
docker-compose ps

# Ver logs em tempo real
docker-compose logs -f

# Reiniciar serviços específicos
docker-compose restart api
docker-compose restart nginx

# Parar sistema
docker-compose down

# Iniciar sistema
docker-compose up -d

# Rebuild completo
docker-compose down -v
docker-compose up --build -d
```

### Gerenciamento do Banco

```bash
# Acessar SQLite diretamente
sqlite3 database/users.db

# Executar query específica
sqlite3 database/users.db "SELECT * FROM users LIMIT 5;"

# Backup manual
cp database/users.db database/backups/manual_$(date +%Y%m%d_%H%M%S).db

# Restaurar backup
cp database/backups/users_backup_YYYYMMDD_HHMMSS.db database/users.db
docker-compose restart api
```

### Anonimização e Logs

```bash
# Executar anonimização manualmente
./scripts/anonymize_pii.sh

# Ver logs de anonimização
tail -n 50 logs/anonymization.log

# Ver logs de cron
tail -n 50 logs/cron.log

# Limpar logs antigos
find logs/ -name "*.log" -mtime +30 -delete
```

## 🎛️ Arquitetura do Sistema

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Internet     │◄──►│     NGINX       │◄──►│   API Node.js   │
│   (Port 80)     │    │   (Port 80)     │    │   (Port 3000)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                               ┌─────────────────┐    ┌─────────────────┐
                               │   SQLite DB     │◄──►│  Volume Mount   │
                               │  (Container)    │    │ /database/*.db  │
                               └─────────────────┘    └─────────────────┘
                                        ▲
                                        │
                               ┌─────────────────┐
                               │   Cronjob PII   │
                               │  (Daily 2 AM)   │
                               └─────────────────┘
```

## 🔒 Sistema de Anonimização PII

### Dados Anonimizados Automaticamente

- **Nome completo**: Prefixo "ANONIMIZADO\_" + nome fictício
- **CPF**: Gerado aleatoriamente no formato XXX.XXX.XXX-XX
- **RG**: Gerado aleatoriamente no formato XX.XXX.XXX-X
- **Telefone**: Gerado com DDD válido + 9 dígitos
- **Endereço**: Endereços fictícios mas realistas

### Processo de Anonimização

1. **Backup**: Cria backup automático antes de modificar
2. **Identificação**: Localiza registros não-anonimizados
3. **Geração**: Cria dados fictícios mas consistentes
4. **Atualização**: Substitui dados PII por versões anonimizadas
5. **Verificação**: Confirma integridade e ausência de duplicatas
6. **Restart**: Reinicia API para aplicar mudanças
7. **Cleanup**: Remove logs e backups antigos

### Agendamento

```bash
# Execução automática diária às 2h da manhã
0 2 * * * /caminho/para/scripts/anonymize_pii.sh

# Para modificar horário, editar crontab
crontab -e
```

## 🚨 Monitoramento e Troubleshooting

### Verificações de Saúde

```bash
# API responsiva?
curl -s http://localhost/health | jq .

# Containers rodando?
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Banco acessível?
docker exec expertai_database sqlite3 /data/users.db "SELECT COUNT(*) FROM users;"

# Internet funcionando?
docker exec expertai_api ping -c 1 google.com
```

### Problemas Comuns e Soluções

**🔴 Container não inicia**

```bash
docker-compose logs [container_name]
docker-compose down -v && docker-compose up --build -d
```

**🔴 API não responde**

```bash
curl http://localhost:3000/health  # Teste direto
docker-compose restart api
docker-compose logs api
```

**🔴 Banco não conecta**

```bash
ls -la database/  # Verificar arquivos
docker-compose restart database
docker volume ls  # Verificar volumes
```

**🔴 Anonimização falha**

```bash
chmod +x scripts/anonymize_pii.sh
./scripts/anonymize_pii.sh  # Testar manualmente
tail -f logs/anonymization.log  # Ver erros
```

**🔴 NGINX não proxy**

```bash
docker-compose logs nginx
curl -I http://localhost/  # Ver headers
```

## 📈 Endpoints da API

### Endpoints de Usuários

| Método | Endpoint                  | Descrição                |
| ------ | ------------------------- | ------------------------ |
| GET    | `/health`                 | Status da API            |
| GET    | `/`                       | Informações da API       |
| GET    | `/api/users`              | Listar usuários          |
| GET    | `/api/users/:id`          | Obter usuário específico |
| POST   | `/api/users`              | Criar novo usuário       |
| PUT    | `/api/users/:id`          | Atualizar usuário        |
| DELETE | `/api/users/:id`          | Deletar usuário          |
| GET    | `/api/users/search/:term` | Buscar usuários          |

### Endpoints de Logs 📝 **NOVO!**

| Método | Endpoint              | Descrição                           |
| ------ | --------------------- | ----------------------------------- |
| POST   | `/api/logs/access`    | Registrar log de acesso             |
| POST   | `/api/logs/operation` | Registrar log de operação           |
| GET    | `/api/logs/access`    | Listar logs de acesso (últimos 100) |
| GET    | `/api/logs/operation` | Listar logs de operação (últimos 100)|
| GET    | `/api/logs/health`    | Status do sistema de logs           |

### Exemplos de Uso - Usuários

```bash
# Criar usuário
curl -X POST http://localhost/api/users \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Ana Costa","email":"ana@teste.com","cpf":"98765432100", "address":"Av. Paulista"}'

# Buscar usuário por ID
curl http://localhost/api/users/1

# Buscar por termo
curl http://localhost/api/users/search/ana

# Atualizar usuário
curl -X PUT http://localhost/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"phone":"11888777666"}'

# Deletar usuário
curl -X DELETE http://localhost/api/users/1
```

### Exemplos de Uso - Logs 📝 **NOVO!**

```bash
# Registrar log de acesso
curl -X POST http://localhost/api/logs/access \
  -H "Content-Type: application/json" \
  -d '{
    "user": "admin",
    "action": "LOGIN",
    "resource": "/admin/dashboard",
    "status": "SUCCESS",
    "details": "Login bem-sucedido via interface web"
  }'

# Registrar log de operação
curl -X POST http://localhost/api/logs/operation \
  -H "Content-Type: application/json" \
  -d '{
    "user": "expertai_anonymizer",
    "operation": "ANONYMIZATION",
    "status": "COMPLETED",
    "records_affected": 150,
    "duration_ms": 2500,
    "details": "Anonimização executada com sucesso"
  }'

# Listar logs de acesso (últimos 50)
curl "http://localhost/api/logs/access?limit=50"

# Listar logs de operação
curl http://localhost/api/logs/operation

# Verificar status do sistema de logs
curl http://localhost/api/logs/health
# Retorna: status dos arquivos xp_access.log e xp_operation.log
```

## 📝 Sistema de Logs **NOVO!**

### Arquitetura de Logs

O ExpertAI implementa um sistema completo de logging em dois níveis:

1. **Logs Locais**: Arquivos no diretório `./logs/` (montado em `/var/log` no container)
2. **Logs via API**: Endpoints REST para receber e consultar logs

#### Arquivos de Log

| Arquivo               | Localização         | Propósito                                    |
| --------------------- | ------------------- | -------------------------------------------- |
| `xp_access.log`       | `/var/log/`         | Logs de acesso e autenticação                |
| `xp_operation.log`    | `/var/log/`         | Logs de operações do sistema                 |
| `anonymization.log`   | `./logs/`           | Logs do script de anonimização               |
| `cron.log`            | `./logs/`           | Logs de execução do cronjob                  |

### Como Funciona

#### 1. Script de Anonimização Registra Logs

O script `anonymize_pii.sh` automaticamente envia logs para a API durante sua execução:

```bash
# Início da operação
POST /api/logs/operation
{
  "user": "expertai_anonymizer",
  "operation": "ANONYMIZATION",
  "status": "STARTED",
  "details": "Iniciando anonimização de dados PII"
}

# Conclusão
POST /api/logs/operation
{
  "user": "expertai_anonymizer",
  "operation": "ANONYMIZATION",
  "status": "COMPLETED",
  "records_affected": 150,
  "duration_ms": 2500
}
```

#### 2. Logs Armazenados em Arquivos

Os logs são gravados em arquivos JSON estruturados:

```bash
# Exemplo de linha em xp_operation.log
[2025-10-20T14:30:25.123Z] [expertai_anonymizer] [STARTED] {"user":"expertai_anonymizer","operation":"ANONYMIZATION","target":"users.db","status":"STARTED","duration_ms":0,"records_affected":0,"details":"Iniciando anonimização de dados PII"}
```

### Campos dos Logs

#### Log de Acesso (`/api/logs/access`)

| Campo      | Tipo   | Obrigatório | Descrição                               |
| ---------- | ------ | ----------- | --------------------------------------- |
| user       | string | Sim         | Usuário que realizou a ação             |
| ip         | string | Não         | Endereço IP (auto-detectado se omitido) |
| action     | string | Sim         | Ação realizada (LOGIN, LOGOUT, etc)     |
| resource   | string | Sim         | Recurso acessado                        |
| status     | enum   | Sim         | SUCCESS, FAILURE, WARNING               |
| details    | string | Não         | Informações adicionais                  |

#### Log de Operação (`/api/logs/operation`)

| Campo            | Tipo   | Obrigatório | Descrição                                    |
| ---------------- | ------ | ----------- | -------------------------------------------- |
| user             | string | Sim         | Usuário que executou a operação              |
| operation        | string | Sim         | Nome da operação                             |
| target           | string | Não         | Alvo da operação (banco, arquivo, etc)       |
| status           | enum   | Sim         | STARTED, COMPLETED, FAILED, IN_PROGRESS      |
| duration_ms      | number | Não         | Duração em milissegundos                     |
| records_affected | number | Não         | Quantidade de registros afetados             |
| details          | string | Não         | Informações adicionais                       |

### Visualizar Logs

```bash
# Ver logs de acesso em tempo real
tail -f logs/xp_access.log

# Ver logs de operação
tail -f logs/xp_operation.log

# Ver últimos 20 logs de anonimização
tail -n 20 logs/anonymization.log

# Buscar por usuário específico
grep "expertai_anonymizer" logs/xp_operation.log

# Ver logs via API (últimos 100)
curl http://localhost/api/logs/operation | jq .
```

## 👥 Usuários Linux Dedicados **NOVO!**

### Por Que Usar Usuários Dedicados?

O ExpertAI implementa usuários Linux dedicados seguindo as melhores práticas de segurança:

1. **Princípio do Menor Privilégio**: Cada usuário tem apenas as permissões necessárias
2. **Auditoria**: Logs rastreiam exatamente quem executou cada operação
3. **Isolamento**: Processos rodam com identidades separadas
4. **Segurança**: Minimiza danos em caso de comprometimento

### Usuários Criados

| Usuário               | Grupo      | Função                                  | Permissões                       |
| --------------------- | ---------- | --------------------------------------- | -------------------------------- |
| `expertai_logger`     | `expertai` | Escrita de logs em `/var/log`           | Leitura/escrita em `/var/log`    |
| `expertai_anonymizer` | `expertai` | Execução do script de anonimização      | Leitura/escrita em `database/`   |
| Seu usuário (opcional)| `expertai` | Administração e manutenção              | Acesso completo ao projeto       |

### Estrutura de Permissões

```bash
# Diretórios e permissões
/opt/ExpertAI/
├── logs/              # rwxrwxr-x (root:expertai)
│   ├── xp_access.log  # rw-rw-r-- (root:expertai)
│   └── xp_operation.log
├── database/          # rwxrwxr-x (expertai_anonymizer:expertai)
│   └── users.db       # rw-rw-r-- (expertai_anonymizer:expertai)
└── scripts/           # rwxr-xr-x (root:expertai)
    └── anonymize_pii.sh  # rwxr-x--- (root:expertai)
```

### Configuração Automática

O script `setup_users.sh` configura tudo automaticamente:

```bash
sudo ./scripts/setup_users.sh
```

O que é feito:

1. ✅ Cria grupo `expertai`
2. ✅ Cria usuários `expertai_logger` e `expertai_anonymizer`
3. ✅ Configura permissões de diretórios
4. ✅ Cria configuração sudo em `/etc/sudoers.d/expertai`
5. ✅ Permite execução do script sem senha
6. ✅ (Opcional) Adiciona seu usuário ao grupo

### Configuração Manual de Sudo

O arquivo `/etc/sudoers.d/expertai` contém:

```bash
# Permitir usuário anonymizer executar script sem senha
expertai_anonymizer ALL=(root) NOPASSWD: /opt/ExpertAI/scripts/anonymize_pii.sh

# Permitir usuário anonymizer reiniciar docker-compose
expertai_anonymizer ALL=(root) NOPASSWD: /usr/bin/docker-compose restart api

# Permitir usuário logger escrever em /var/log
expertai_logger ALL=(root) NOPASSWD: /usr/bin/tee -a /var/log/xp_*.log
```

### Executar Como Usuário Dedicado

```bash
# Executar anonimização como usuário dedicado
sudo -u expertai_anonymizer /opt/ExpertAI/scripts/anonymize_pii.sh

# Ver logs criados pelo usuário
sudo -u expertai_logger tail -f /var/log/xp_operation.log

# Verificar identidade do usuário
sudo -u expertai_anonymizer whoami
# Retorna: expertai_anonymizer
```

### Verificar Configuração

```bash
# Ver grupos do sistema
getent group expertai

# Ver usuários criados
id expertai_logger
id expertai_anonymizer

# Ver permissões dos diretórios
ls -la /opt/ExpertAI/logs/
ls -la /opt/ExpertAI/database/

# Testar sudo
sudo -u expertai_anonymizer -l
# Deve mostrar os comandos permitidos sem senha
```

## 🔐 Segurança e Melhores Práticas

### Permissões de Arquivos

```bash
# Verificar permissões dos logs
ls -l logs/
# Deve mostrar: -rw-rw-r-- (644)

# Verificar permissões do banco
ls -l database/users.db
# Deve mostrar: -rw-rw-r-- (664)

# Verificar permissões dos scripts
ls -l scripts/*.sh
# Deve mostrar: -rwxr-x--- (750)
```

### Auditoria de Logs

```bash
# Ver quem executou operações de anonimização
grep "ANONYMIZATION" logs/xp_operation.log | grep "COMPLETED"

# Contar anonimizações executadas
grep -c "ANONYMIZATION.*COMPLETED" logs/xp_operation.log

# Ver logs de falhas
grep "FAILED" logs/xp_operation.log

# Estatísticas de registros anonimizados
grep "records_affected" logs/xp_operation.log | \
  grep -oP '"records_affected":\d+' | \
  awk -F: '{sum+=$2} END {print "Total:", sum}'
```

### Backup e Rotação de Logs

```bash
# Backups automáticos (mantém últimos 10)
ls -lh database/backups/

# Limpeza automática de logs antigos (>30 dias)
# Executada automaticamente pelo script de anonimização

# Rotação manual de logs
sudo logrotate /etc/logrotate.d/expertai
```

## 📚 Recursos Criados e Configurações

### Arquivos de Configuração

| Arquivo                      | Descrição                                   |
| ---------------------------- | ------------------------------------------- |
| `docker-compose.yml`         | Orquestração de containers                  |
| `api/routes/logs.js`         | Endpoints de logging                        |
| `api/server.js`              | Servidor Express com rotas de logs          |
| `scripts/anonymize_pii.sh`   | Script de anonimização com logging via API  |
| `scripts/setup_users.sh`     | Configuração de usuários Linux dedicados    |
| `scripts/setup_cronjob.sh`   | Configuração de cronjob                     |
| `/etc/sudoers.d/expertai`    | Permissões sudo para usuários               |

### Volumes Docker

```yaml
volumes:
  - ./database:/app/database  # Banco SQLite compartilhado
  - ./logs:/var/log           # Logs compartilhados (NOVO!)
```

### Variáveis de Ambiente

```bash
# No container API
NODE_ENV=production
DB_PATH=/app/database/users.db
LOG_DIR=/var/log  # NOVO!

# No script de anonimização
API_URL=http://localhost:3000  # URL da API para envio de logs
```

### Portas Expostas

| Porta | Serviço | Descrição                    |
| ----- | ------- | ---------------------------- |
| 80    | NGINX   | Proxy reverso HTTP           |
| 443   | NGINX   | Proxy reverso HTTPS (futuro) |
| 3000  | Node.js | API REST (interno)           |

## 🎥 Demonstração em Vídeo

[Link para vídeo de demonstração - Máximo 6 minutos]

O vídeo demonstra:

1. ✅ Instalação e deploy completo do sistema
2. ✅ Configuração de usuários Linux dedicados
3. ✅ Criação de usuários via API
4. ✅ Execução manual do script de anonimização
5. ✅ Visualização de logs via API e arquivos
6. ✅ Verificação do cronjob automático
7. ✅ Consulta aos logs de operação
8. ✅ Demonstração de permissões e segurança

---

## 📞 Suporte e Contato

Para questões, problemas ou sugestões, abra uma issue no repositório do projeto.

**Desenvolvido por ExpertAI** - Sistema de Gerenciamento de Usuários com PII Anonymization
