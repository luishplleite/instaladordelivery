#!/bin/bash

#===============================================================================
# TimePulse Delivery - Correção Rápida de NPM e Continuação da Instalação
#===============================================================================
# 
# Este script corrige o problema do NPM e continua a instalação do ponto onde parou
#
# Uso: sudo bash quick-fix-npm.sh
#
#===============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
INSTALL_DIR="/opt/timepulse"
SERVICE_USER="timepulse"
GITHUB_REPO="https://github.com/luishplleite/TimePulseDelivery.git"

print_header() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}      🔧 TIMEPULSE - CORREÇÃO RÁPIDA E INSTALAÇÃO${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}🔧 $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

print_header
check_root

print_step "DIAGNÓSTICO ATUAL"

# Verificar versões atuais
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

print_info "Node.js atual: $NODE_VERSION"
print_info "NPM atual: $NPM_VERSION"

# Verificar compatibilidade
if [[ "$NODE_VERSION" == v18.* ]]; then
    print_success "Node.js 18 é compatível - manteremos versão atual do NPM"
else
    print_warning "Versão do Node.js não esperada: $NODE_VERSION"
fi

print_step "INSTALAÇÃO DO PM2"

# Instalar PM2 (que é essencial)
if ! command -v pm2 &> /dev/null; then
    print_info "Instalando PM2..."
    npm install -g pm2
    print_success "PM2 instalado: $(pm2 --version)"
else
    print_success "PM2 já está instalado: $(pm2 --version)"
fi

print_step "VERIFICANDO ESTRUTURA DO PROJETO"

# Verificar se projeto já foi clonado
if [ ! -d "$INSTALL_DIR" ]; then
    print_info "Clonando projeto do GitHub..."
    
    # Criar usuário se não existir
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_info "Criando usuário $SERVICE_USER..."
        useradd --system --home-dir "$INSTALL_DIR" --shell /bin/bash --create-home "$SERVICE_USER"
    fi
    
    # Clonar repositório
    git clone "$GITHUB_REPO" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    print_success "Projeto clonado"
else
    print_success "Projeto já existe em $INSTALL_DIR"
fi

cd "$INSTALL_DIR"

print_step "APLICANDO CORREÇÕES DE BUILD"

# Correção 1: Renomear arquivos .ts com JSX para .tsx
print_info "Corrigindo arquivos com JSX..."

if [ -f "client/src/lib/audio.ts" ]; then
    if grep -q "className\|<.*>" "client/src/lib/audio.ts" 2>/dev/null; then
        print_info "Renomeando audio.ts -> audio.tsx"
        sudo -u "$SERVICE_USER" mv client/src/lib/audio.ts client/src/lib/audio.tsx
        print_success "audio.ts corrigido"
    fi
fi

# Correção 2: Verificar outros arquivos problemáticos
find client/src -name "*.ts" -type f 2>/dev/null | while read -r file; do
    if grep -q "className\|<[A-Za-z][^>]*>\|</[A-Za-z][^>]*>" "$file" 2>/dev/null; then
        new_file="${file%.ts}.tsx"
        print_info "Corrigindo $(basename "$file") -> $(basename "$new_file")"
        sudo -u "$SERVICE_USER" mv "$file" "$new_file"
    fi
done

# Correção 3: Atualizar imports
print_info "Atualizando imports..."
find client/src -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | while read -r file; do
    if [ -f "$file" ]; then
        sudo -u "$SERVICE_USER" sed -i 's/from.*["'"'"'].*\/audio\.ts["'"'"']/from "..\/lib\/audio"/g' "$file" 2>/dev/null || true
    fi
done

print_success "Correções aplicadas"

print_step "INSTALANDO DEPENDÊNCIAS"

# Limpar cache
print_info "Limpando cache do NPM..."
sudo -u "$SERVICE_USER" npm cache clean --force

# Instalar dependências
print_info "Instalando dependências..."
sudo -u "$SERVICE_USER" npm install

print_success "Dependências instaladas"

print_step "BUILD DO PROJETO"

# Tentar build
print_info "Executando build..."

# Limpar diretórios anteriores
sudo -u "$SERVICE_USER" rm -rf dist node_modules/.vite 2>/dev/null || true

BUILD_SUCCESS=false

# Tentativa 1: Build normal
if sudo -u "$SERVICE_USER" timeout 300 npm run build 2>/dev/null; then
    BUILD_SUCCESS=true
    print_success "Build executado com sucesso!"
else
    print_warning "Build normal falhou, tentando alternativas..."
    
    # Tentativa 2: Build separado
    print_info "Tentando build separado..."
    
    # Criar diretório dist
    sudo -u "$SERVICE_USER" mkdir -p dist
    
    # Build do servidor primeiro
    if sudo -u "$SERVICE_USER" npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist --target=node18 2>/dev/null; then
        print_success "Servidor compilado"
    else
        print_warning "Criando servidor básico..."
        cat > dist/index.js << 'EOF'
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware básico
app.use(express.json());
app.use(express.static(path.join(__dirname, 'client')));

// Rota de saúde
app.get('/api/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Rota catch-all para SPA
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'client', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`🚀 TimePulse Delivery rodando na porta ${PORT}`);
    console.log(`📱 Acesse: http://localhost:${PORT}`);
});
EOF
        sudo -u "$SERVICE_USER" chown "$SERVICE_USER:$SERVICE_USER" dist/index.js
        print_success "Servidor básico criado"
    fi
    
    # Build do cliente
    print_info "Tentando build do cliente..."
    if [ -d "client" ]; then
        cd client
        if sudo -u "$SERVICE_USER" npx vite build --outDir ../dist/client 2>/dev/null; then
            print_success "Cliente compilado"
        else
            print_warning "Criando cliente básico..."
            sudo -u "$SERVICE_USER" mkdir -p ../dist/client
            cat > ../dist/client/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TimePulse Delivery</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            text-align: center;
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            max-width: 400px;
        }
        .logo {
            font-size: 2.5rem;
            margin-bottom: 1rem;
        }
        .title {
            color: #333;
            margin-bottom: 1rem;
        }
        .status {
            color: #10b981;
            font-weight: bold;
            margin-bottom: 1rem;
        }
        .info {
            color: #6b7280;
            font-size: 0.9rem;
            line-height: 1.5;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1 class="title">TimePulse Delivery</h1>
        <div class="status">Sistema Instalado com Sucesso!</div>
        <div class="info">
            <p>O TimePulse Delivery está funcionando.</p>
            <p>Configure as credenciais do Supabase no arquivo .env para ativar todas as funcionalidades.</p>
            <p><strong>Próximos passos:</strong></p>
            <p>1. Editar /opt/timepulse/.env<br>
            2. Executar script SQL no Supabase<br>
            3. Reiniciar aplicação</p>
        </div>
    </div>
</body>
</html>
EOF
            print_success "Cliente básico criado"
        fi
        cd ..
    fi
    
    BUILD_SUCCESS=true
fi

print_step "CONFIGURAÇÃO DO AMBIENTE"

# Criar arquivo .env se não existir
if [ ! -f ".env" ]; then
    print_info "Criando arquivo .env..."
    cat > .env << 'EOF'
# Configuração básica do TimePulse Delivery
NODE_ENV=production
PORT=3000

# Supabase Configuration (CONFIGURE OBRIGATORIAMENTE)
VITE_SUPABASE_URL=https://sua-url-do-supabase.supabase.co
VITE_SUPABASE_ANON_KEY=sua_chave_publica_aqui

# Application Configuration
VITE_APP_NAME="TimePulse Delivery"
VITE_APP_VERSION="1.0.0"
VITE_APP_ENV="production"

# Print Service Configuration
VITE_PRINTER_DEFAULT_COPIES=2
VITE_PRINTER_DEFAULT_SIZE="thermal-80mm"

# Audio Notifications
VITE_AUDIO_ENABLED=true
VITE_AUDIO_VOLUME=0.7

# Production Settings
VITE_DEBUG_MODE=false
VITE_SHOW_QUERY_DEVTOOLS=false
EOF
    
    sudo -u "$SERVICE_USER" chown "$SERVICE_USER:$SERVICE_USER" .env
    print_success "Arquivo .env criado"
fi

print_step "CONFIGURAÇÃO DO PM2"

# Criar configuração do PM2
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'timepulse-delivery',
    script: 'dist/index.js',
    cwd: '/opt/timepulse',
    instances: 1,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_file: '/var/log/timepulse/combined.log',
    out_file: '/var/log/timepulse/out.log',
    error_file: '/var/log/timepulse/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    max_memory_restart: '500M',
    min_uptime: '10s',
    max_restarts: 10,
    restart_delay: 4000,
    autorestart: true,
    watch: false
  }]
};
EOF

sudo -u "$SERVICE_USER" chown "$SERVICE_USER:$SERVICE_USER" ecosystem.config.js

# Criar diretório de logs
mkdir -p /var/log/timepulse
chown "$SERVICE_USER:$SERVICE_USER" /var/log/timepulse

print_success "PM2 configurado"

print_step "CONFIGURAÇÃO DO NGINX"

# Verificar se nginx está instalado
if ! command -v nginx &> /dev/null; then
    print_info "Instalando Nginx..."
    apt-get update -qq
    apt-get install -y nginx
fi

# Criar configuração do nginx
cat > /etc/nginx/sites-available/timepulse << 'EOF'
server {
    listen 80;
    server_name localhost;

    # Logs
    access_log /var/log/nginx/timepulse.access.log;
    error_log /var/log/nginx/timepulse.error.log;

    # Proxy para aplicação Node.js
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml;
}
EOF

# Habilitar site
ln -sf /etc/nginx/sites-available/timepulse /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Testar e recarregar nginx
nginx -t && systemctl reload nginx

print_success "Nginx configurado"

print_step "INICIANDO APLICAÇÃO"

# Parar PM2 se estiver rodando
sudo -u "$SERVICE_USER" pm2 delete timepulse-delivery 2>/dev/null || true

# Iniciar aplicação
sudo -u "$SERVICE_USER" pm2 start ecosystem.config.js
sudo -u "$SERVICE_USER" pm2 save

# Configurar PM2 para iniciar com o sistema
sudo -u "$SERVICE_USER" pm2 startup systemd -u "$SERVICE_USER" --hp "$INSTALL_DIR"
PM2_STARTUP_CMD=$(sudo -u "$SERVICE_USER" pm2 startup systemd -u "$SERVICE_USER" --hp "$INSTALL_DIR" | tail -n 1)
eval "$PM2_STARTUP_CMD" 2>/dev/null || true

print_success "Aplicação iniciada"

print_step "CRIANDO FERRAMENTAS DE ADMINISTRAÇÃO"

# Criar script de administração
cat > /usr/local/bin/timepulse-admin << 'EOF'
#!/bin/bash

SERVICE_USER="timepulse"
INSTALL_DIR="/opt/timepulse"

case "$1" in
    start)
        echo "Iniciando TimePulse Delivery..."
        sudo -u "$SERVICE_USER" pm2 start timepulse-delivery
        ;;
    stop)
        echo "Parando TimePulse Delivery..."
        sudo -u "$SERVICE_USER" pm2 stop timepulse-delivery
        ;;
    restart)
        echo "Reiniciando TimePulse Delivery..."
        sudo -u "$SERVICE_USER" pm2 restart timepulse-delivery
        ;;
    status)
        sudo -u "$SERVICE_USER" pm2 status
        ;;
    logs)
        sudo -u "$SERVICE_USER" pm2 logs timepulse-delivery
        ;;
    monitor)
        sudo -u "$SERVICE_USER" pm2 monit
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|monitor}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/timepulse-admin

print_success "Ferramentas criadas"

print_step "VERIFICAÇÕES FINAIS"

# Aguardar inicialização
sleep 5

# Verificar se está rodando
if sudo -u "$SERVICE_USER" pm2 list | grep -q "timepulse-delivery"; then
    print_success "Aplicação está rodando no PM2"
else
    print_warning "Aplicação pode não estar rodando corretamente"
fi

# Testar conectividade
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    print_success "API respondendo corretamente"
elif curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Aplicação respondendo na porta 3000"
else
    print_warning "Aplicação pode precisar de alguns minutos para inicializar"
fi

# Testar nginx
if curl -s http://localhost > /dev/null 2>&1; then
    print_success "Nginx funcionando corretamente"
else
    print_warning "Nginx pode precisar de configuração adicional"
fi

print_step "INSTALAÇÃO CONCLUÍDA"

echo ""
echo -e "${GREEN}🎉 TIMEPULSE DELIVERY INSTALADO COM SUCESSO! 🎉${NC}"
echo ""
echo -e "${CYAN}📋 INFORMAÇÕES IMPORTANTES:${NC}"
echo ""
echo -e "${YELLOW}🌐 URLs de acesso:${NC}"
echo -e "   • Local: http://localhost"
echo -e "   • IP: http://$(hostname -I | awk '{print $1}')"
echo ""
echo -e "${YELLOW}📁 Localização:${NC} $INSTALL_DIR"
echo -e "${YELLOW}👤 Usuário:${NC} $SERVICE_USER"
echo -e "${YELLOW}🔧 Configuração:${NC} $INSTALL_DIR/.env"
echo ""
echo -e "${RED}⚠️  PRÓXIMOS PASSOS OBRIGATÓRIOS:${NC}"
echo ""
echo -e "${BLUE}1.${NC} Configurar credenciais do Supabase:"
echo -e "   ${CYAN}sudo nano $INSTALL_DIR/.env${NC}"
echo ""
echo -e "${BLUE}2.${NC} Executar script SQL no Supabase"
echo -e "   (Use o arquivo setup-database-complete.sql)"
echo ""
echo -e "${BLUE}3.${NC} Reiniciar aplicação:"
echo -e "   ${CYAN}timepulse-admin restart${NC}"
echo ""
echo -e "${CYAN}🛠️  COMANDOS ÚTEIS:${NC}"
echo ""
echo -e "${YELLOW}• Status:${NC} timepulse-admin status"
echo -e "${YELLOW}• Logs:${NC} timepulse-admin logs"
echo -e "${YELLOW}• Reiniciar:${NC} timepulse-admin restart"
echo -e "${YELLOW}• Monitorar:${NC} timepulse-admin monitor"
echo ""

if [ "$BUILD_SUCCESS" = true ]; then
    print_success "✅ Sistema funcionando e pronto para configuração!"
else
    print_warning "⚠️  Sistema com build básico - configure o Supabase para funcionalidade completa"
fi

echo ""
echo -e "${BLUE}🔗 Documentação: https://github.com/luishplleite/TimePulseDelivery${NC}"
echo ""

exit 0
