# Roteiro de Vídeo - ExpertAI Sistema de Logs e Anonimização

**Duração Total:** 6 minutos
**Data:** Outubro 2024
**Apresentador:** [Seu Nome]

---

## ESTRUTURA DO VÍDEO

### Introdução (30 segundos)
- **Tempo:** 0:00 - 0:30

#### Script:
> "Olá! Neste vídeo vou demonstrar as funcionalidades do ExpertAI, um sistema de gerenciamento de usuários com recursos avançados de logging e anonimização de dados sensíveis. Vamos explorar três funcionalidades principais implementadas: endpoints de logging, script de anonimização com integração API, e sistema de usuários Linux dedicados."

#### O que mostrar:
- Tela inicial com o nome do projeto
- Estrutura de pastas do projeto aberta no editor

---

## BLOCO 1: Endpoints de Logging (1min 30s)

### 1.1 Apresentação da Arquitetura (30s)
- **Tempo:** 0:30 - 1:00

#### Script:
> "Primeiro, vamos ver o sistema de logging. Implementamos endpoints REST em Node.js que recebem logs de acesso e operação, armazenando-os em arquivos no diretório /var/log."

#### O que mostrar:
1. Abrir arquivo [api/routes/logs.js](api/routes/logs.js)
2. Destacar as rotas:
   - POST `/api/logs/access`
   - POST `/api/logs/operation`
   - GET `/api/logs/access`
   - GET `/api/logs/operation`
   - GET `/api/logs/health`
3. Mostrar variáveis de ambiente LOG_DIR

#### Comandos (em terminal):
```bash
# Mostrar estrutura dos arquivos
ls -la logs/
cat logs/xp_access.log | head -5
cat logs/xp_operation.log | head -5
```

---

### 1.2 Demonstração Prática dos Endpoints (1min)
- **Tempo:** 1:00 - 2:00

#### Script:
> "Vamos testar os endpoints. Primeiro vou iniciar a aplicação e em seguida enviar logs de acesso e operação."

#### O que fazer:
1. **Iniciar aplicação**
```bash
docker-compose up -d
docker-compose logs -f api
```

2. **Health check do sistema de logs**
```bash
curl http://localhost:3000/api/logs/health | jq
```

3. **Enviar log de acesso**
```bash
curl -X POST http://localhost:3000/api/logs/access \
  -H "Content-Type: application/json" \
  -d '{
    "user": "demonstracao_user",
    "action": "LOGIN",
    "resource": "/api/users",
    "status": "SUCCESS",
    "details": "Login realizado com sucesso via API"
  }' | jq
```

4. **Enviar log de operação**
```bash
curl -X POST http://localhost:3000/api/logs/operation \
  -H "Content-Type: application/json" \
  -d '{
    "user": "demonstracao_user",
    "operation": "DATABASE_QUERY",
    "target": "users.db",
    "status": "COMPLETED",
    "duration_ms": 45,
    "records_affected": 10,
    "details": "Consulta executada com sucesso"
  }' | jq
```

5. **Consultar logs gravados**
```bash
# Ver logs via API
curl "http://localhost:3000/api/logs/access?limit=5" | jq

# Ver logs nos arquivos
tail -5 logs/xp_access.log
tail -5 logs/xp_operation.log
```

#### Pontos a destacar:
- ✅ Logs são salvos em arquivos locais
- ✅ Formato JSON estruturado
- ✅ Timestamp automático
- ✅ Validação com Joi
- ✅ IP automático do cliente

---

## BLOCO 2: Script de Anonimização com API Logging (2min 30s)

### 2.1 Visão Geral do Script (45s)
- **Tempo:** 2:00 - 2:45

#### Script:
> "Agora vamos ao script de anonimização de PII. Ele automaticamente detecta dados sensíveis, cria backups, anonimiza CPF, RG, telefone e endereços, e envia logs de todas as operações para nossa API."

#### O que mostrar:
1. Abrir [scripts/anonymize_pii.sh](scripts/anonymize_pii.sh)
2. Destacar funções principais:
   - `send_log_to_api()` - linha 30
   - `log_operation()` - linha 45
   - `generate_fake_*()` - funções de geração de dados
   - `anonymize_data()` - função principal
3. Mostrar integração com API (linhas 52-66)

#### Código para destacar:
```bash
# Função que envia logs para API
log_operation() {
    local operation="$1"
    local status="$2"
    local details="${3:-}"
    # ...
    send_log_to_api "operation" "$json_data"
}
```

---

### 2.2 Demonstração da Anonimização (1min 45s)
- **Tempo:** 2:45 - 4:30

#### Script:
> "Vou executar o script. Observe como ele cria backup, processa os registros e envia logs para a API em tempo real."

#### O que fazer:

1. **Preparar ambiente - Adicionar usuários de teste**
```bash
# Criar alguns usuários não-anonimizados
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "João da Silva",
    "email": "joao.silva@example.com",
    "cpf": "12345678901",
    "rg": "123456789",
    "phone": "11987654321",
    "address": "Rua Teste, 123"
  }'

curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Maria Santos",
    "email": "maria.santos@example.com",
    "cpf": "98765432109",
    "rg": "987654321",
    "phone": "21987654321",
    "address": "Av. Principal, 456"
  }'
```

2. **Consultar dados ANTES da anonimização**
```bash
curl http://localhost:3000/api/users | jq '.data[] | {id, full_name, cpf, rg}'
```

3. **Executar script de anonimização**
```bash
# Executar
./scripts/anonymize_pii.sh

# Em outro terminal, monitorar logs
tail -f logs/anonymization.log
```

4. **Mostrar logs sendo enviados para API durante execução**
```bash
# Ver logs de operação em tempo real
curl "http://localhost:3000/api/logs/operation?limit=10" | jq
```

5. **Consultar dados DEPOIS da anonimização**
```bash
curl http://localhost:3000/api/users | jq '.data[] | {id, full_name, cpf, rg}'
```

6. **Verificar backup criado**
```bash
ls -lh database/backups/
```

#### Pontos a destacar:
- ✅ Backup automático antes de anonimizar
- ✅ Logs enviados para API (BACKUP STARTED, COMPLETED)
- ✅ Logs enviados para API (ANONYMIZATION STARTED, COMPLETED)
- ✅ Dados sensíveis substituídos por valores fake
- ✅ Prefixo "ANONIMIZADO_" nos nomes
- ✅ Reinicialização automática da API
- ✅ Duração e quantidade de registros processados

---

## BLOCO 3: Usuários Linux Dedicados (1min 30s)

### 3.1 Apresentação do Sistema de Usuários (45s)
- **Tempo:** 4:30 - 5:15

#### Script:
> "Para garantir segurança, implementamos usuários Linux dedicados. O 'expertai_logger' escreve logs, e o 'expertai_anonymizer' executa scripts de anonimização, seguindo o princípio de menor privilégio."

#### O que mostrar:
1. Abrir [scripts/setup_users.sh](scripts/setup_users.sh)
2. Destacar:
   - Criação de grupo `expertai` (linha 26)
   - Usuário `expertai_logger` (linha 38)
   - Usuário `expertai_anonymizer` (linha 48)
   - Configuração de permissões (linhas 56-90)
   - Arquivo sudoers (linhas 92-112)

#### Código para destacar:
```bash
# Usuários criados
LOG_USER="expertai_logger"
ANONYMIZE_USER="expertai_anonymizer"
GROUP_NAME="expertai"

# Permissões sudo
$ANONYMIZE_USER ALL=(root) NOPASSWD: ${SCRIPTS_DIR}/anonymize_pii.sh
$LOG_USER ALL=(root) NOPASSWD: /usr/bin/tee -a /var/log/xp_*.log
```

---

### 3.2 Demonstração de Uso (45s)
- **Tempo:** 5:15 - 6:00

#### Script:
> "Em um servidor Linux de produção, executaríamos assim. Vou simular mostrando a estrutura de permissões e como os comandos seriam executados."

#### O que mostrar:

**NOTA:** Como você provavelmente está em macOS/desenvolvimento, mostrar apenas visualmente:

1. **Mostrar conteúdo do script**
```bash
cat scripts/setup_users.sh | grep -A 5 "useradd"
```

2. **Mostrar sudoers que seria criado**
```bash
cat scripts/setup_users.sh | grep -A 10 "SUDOERS_FILE"
```

3. **Simular comandos que seriam executados (APENAS MOSTRAR, NÃO EXECUTAR)**
```bash
# Comando que seria executado em produção:
# sudo ./scripts/setup_users.sh

# Executar anonimização como usuário dedicado:
# sudo -u expertai_anonymizer /opt/ExpertAI/scripts/anonymize_pii.sh

# Verificar permissões:
# sudo -u expertai_anonymizer -l
```

4. **Mostrar estrutura de permissões esperada**
```bash
# Mostrar no código a estrutura planejada
cat scripts/setup_users.sh | grep -A 15 "Resumo:"
```

#### Pontos a destacar:
- ✅ Usuários separados por função
- ✅ Grupo compartilhado `expertai`
- ✅ Permissões sudo específicas (sem senha)
- ✅ Diretórios com permissões corretas (775/664)
- ✅ Auditoria clara (logs mostram qual usuário executou)

---

## CONCLUSÃO (30 segundos)

### Script:
> "Demonstramos três funcionalidades principais: endpoints de logging REST que armazenam logs estruturados, script de anonimização que integra com a API para registrar todas as operações, e sistema de usuários Linux dedicados para segurança e auditoria. Todas essas funcionalidades trabalham juntas para criar um sistema robusto de gerenciamento de dados sensíveis. Obrigado!"

### O que mostrar:
1. Voltar para visão geral do projeto
2. Mostrar estrutura final de arquivos:
```bash
tree -L 2 -I node_modules
```

3. Resumo visual:
```
✅ Logs REST API (Node.js + Express)
✅ Anonimização automatizada (Bash + SQLite)
✅ Usuários Linux dedicados (Security)
```

---

## CHECKLIST TÉCNICO PRÉ-GRAVAÇÃO

### Preparação do ambiente:

- [ ] Docker Compose iniciado (`docker-compose up -d`)
- [ ] API respondendo em `http://localhost:3000`
- [ ] Banco de dados limpo ou com dados de teste
- [ ] Logs vazios ou com poucos registros
- [ ] Terminal configurado com fonte legível
- [ ] Editor de código aberto (VSCode recomendado)
- [ ] Ferramentas instaladas:
  - [ ] `curl`
  - [ ] `jq` (para formatar JSON)
  - [ ] `sqlite3`

### Arquivos a ter abertos:
1. `api/routes/logs.js`
2. `scripts/anonymize_pii.sh`
3. `scripts/setup_users.sh`
4. `CLAUDE.md` (para referência)

### Comandos úteis durante a gravação:

```bash
# Limpar logs
> logs/xp_access.log
> logs/xp_operation.log
> logs/anonymization.log

# Resetar banco de dados
rm database/users.db
docker-compose restart api

# Verificar status
docker-compose ps
curl http://localhost:3000/health | jq
```

---

## DICAS DE GRAVAÇÃO

### Voz e Ritmo:
- Fale de forma clara e pausada
- Evite "hmmm", "ahhh", "né"
- Faça pausas de 2 segundos entre demonstrações
- Ritmo: 1 funcionalidade a cada 2 minutos

### Visual:
- Aumente o zoom do terminal (fonte 16-18pt)
- Use tema escuro para melhor contraste
- Destaque com seta do mouse ou zoom os pontos importantes
- Copie/cole comandos longos (não digite ao vivo)

### Edição:
- Acelere partes repetitivas (instalação, espera)
- Mantenha velocidade normal nas explicações
- Adicione legendas nos pontos principais
- Música de fundo baixa (opcional)

### Estrutura visual sugerida:
```
┌─────────────────────────────────────┐
│  EDITOR (lado esquerdo 60%)         │
│  - Código destacado                 │
│  - Linha atual em foco              │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│  TERMINAL (lado direito 40%)        │
│  - Comandos executados              │
│  - Outputs visíveis                 │
└─────────────────────────────────────┘
```

---

## TROUBLESHOOTING

### Se algo der errado durante a gravação:

**API não responde:**
```bash
docker-compose restart api
docker-compose logs api
```

**Logs não aparecem:**
```bash
# Verificar permissões
ls -la logs/
# Recriar diretório
mkdir -p logs
```

**Banco de dados corrompido:**
```bash
# Restaurar do backup
cp database/backups/users_backup_*.db database/users.db
docker-compose restart api
```

**Comandos curl falhando:**
```bash
# Verificar se API está rodando
curl http://localhost:3000/health

# Verificar porta
netstat -an | grep 3000
```

---

## TIMING SUMMARY

| Seção | Tempo | Duração |
|-------|-------|---------|
| Introdução | 0:00 - 0:30 | 30s |
| Endpoints - Arquitetura | 0:30 - 1:00 | 30s |
| Endpoints - Demo | 1:00 - 2:00 | 1min |
| Anonimização - Visão | 2:00 - 2:45 | 45s |
| Anonimização - Demo | 2:45 - 4:30 | 1min 45s |
| Usuários - Apresentação | 4:30 - 5:15 | 45s |
| Usuários - Demo | 5:15 - 6:00 | 45s |
| **TOTAL** | **6:00** | **6min** |

---

## RECURSOS ADICIONAIS

### Links para documentação:
- Express.js: https://expressjs.com
- SQLite: https://www.sqlite.org
- Docker Compose: https://docs.docker.com/compose
- Joi Validation: https://joi.dev

### Comandos de referência rápida:
```bash
# Ver este roteiro
cat ROTEIRO_VIDEO.md

# Verificar todos os endpoints
curl http://localhost:3000/api/logs/health | jq

# Monitorar logs em tempo real
tail -f logs/*.log

# Status completo do sistema
docker-compose ps && \
curl http://localhost:3000/health && \
ls -lh database/ && \
ls -lh logs/
```

---

**BOA GRAVAÇÃO! 🎬**
