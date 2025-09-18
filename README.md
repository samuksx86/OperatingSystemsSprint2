# 🚀 ExpertAI - Guia de Início Rápido

## 🎯 Requisitos Cumpridos ✅

✅ **25%** - Servidor Linux (Debian/Ubuntu) com Docker, NGINX e acesso à internet
✅ **25%** - SQLite em container Docker com volume externo compartilhado
✅ **25%** - API Node.js com endpoints para CRUD de usuários
✅ **25%** - Cronjob automático para anonimização de dados PII

### Para Servidor Linux (Ubuntu/Debian)

```bash
# 1. Fazer upload dos arquivos para o servidor
scp -r ExpertAI/ user@servidor:/opt/
ssh user@servidor

# 2. Entrar no diretório e executar deploy
cd /opt/ExpertAI
chmod +x scripts/*.sh
./scripts/deploy.sh

# 3. Configurar cronjob de anonimização
./scripts/setup_cronjob.sh
```

### Para Desenvolvimento Local (macOS/Linux/Windows)

```bash
# 1. Entrar no diretório do projeto
cd ExpertAI

# 2. Iniciar sistema completo
docker-compose up --build -d

# 3. Configurar cronjob (opcional para desenvolvimento)
chmod +x scripts/*.sh
./scripts/setup_cronjob.sh
```

**Acesso:**

- 🌐 API Principal: `http://localhost/` ou `http://SEU_IP/`
- 💚 Health Check: `http://localhost/health`
- 📊 Usuários: `http://localhost/api/users`

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

### Principais Endpoints

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

### Exemplos de Uso

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
