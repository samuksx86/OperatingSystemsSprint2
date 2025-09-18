FROM node:18-alpine

# Instalar SQLite e build tools
RUN apk add --no-cache sqlite python3 make g++

# Criar diretório da aplicação
WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências e rebuild native modules
RUN npm install --production && npm rebuild sqlite3

# Copiar código da aplicação (exceto node_modules)
COPY server.js ./
COPY config/ ./config/
COPY routes/ ./routes/

# Criar diretório para o banco de dados
RUN mkdir -p /app/database

# Expor porta
EXPOSE 3000

# Comando para iniciar a aplicação
CMD ["npm", "start"]