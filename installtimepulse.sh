#!/bin/bash

#===============================================================================
# TimePulse Delivery - Script de Instalação Completa para Debian/Ubuntu
#===============================================================================
# 
# Este script automatiza a instalação completa do TimePulse Delivery
# Inclui todas as dependências, configurações e setup inicial
#
# Uso: sudo bash install-timepulse-debian.sh
#
#===============================================================================

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
PROJECT_NAME="TimePulseDelivery"
GITHUB_REPO="https://github.com/luishplleite/TimePulseDelivery.git"
INSTALL_DIR="/opt/timepulse"
SERVICE_USER="timepulse"
NODE_VERSION="18"

#===============================================================================
# FUNÇÕES AUXILIARES
#===============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}                    TIMEPULSE DELIVERY - INSTALAÇÃO DEBIAN${NC}"
    echo -e "${CYAN}=============================================================================${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}🔧 $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..80})${NC}"
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
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

check_os() {
    if ! command -v apt-get &> /dev/null; then
        print_error "Este script é apenas para sistemas Debian/Ubuntu"
        exit 1
    fi
}

prompt_user() {
    echo -e "${CYAN}$1${NC}"
    read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."
}

#===============================================================================
# VERIFICAÇÕES INICIAIS
#===============================================================================

print_header

print_step "VERIFICAÇÕES INICIAIS"
check_root
check_os

print_info "Sistema operacional: $(lsb_release -d | cut -f2)"
print_info "Arquitetura: $(uname -m)"
print_success "Verificações iniciais concluídas"

#===============================================================================
# ATUALIZAÇÃO DO SISTEMA
#===============================================================================

print_step "ATUALIZANDO SISTEMA"
print_info "Atualizando lista de pacotes..."
apt-get update -qq

print_info "Atualizando pacotes instalados..."
apt-get upgrade -y -qq

print_success "Sistema atualizado"

#===============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS BÁSICAS
#===============================================================================

print_step "INSTALANDO DEPENDÊNCIAS BÁSICAS"

PACKAGES=(
    "curl"
    "wget" 
    "git"
    "build-essential"
    "software-properties-common"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "unzip"
    "htop"
    "nano"
    "vim"
    "nginx"
    "ufw"
    "fail2ban"
    "supervisor"
    "sqlite3"
    "postgresql-client"
)

for package in "${PACKAGES[@]}"; do
    print_info "Instalando $package..."
    apt-get install -y -qq "$package"
done

print_success "Dependências básicas instaladas"

#===============================================================================
# INSTALAÇÃO DO NODE.JS
#===============================================================================

print_step "INSTALANDO NODE.JS ${NODE_VERSION}"

# Remover versões antigas do Node.js
print_info "Removendo versões antigas do Node.js..."
apt-get remove -y -qq nodejs npm 2>/dev/null || true

# Adicionar repositório oficial do Node.js
print_info "Adicionando repositório oficial do Node.js..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

# Instalar Node.js
print_info "Instalando Node.js ${NODE_VERSION}..."
apt-get install -y -qq nodejs

# Verificar instalação
NODE_VERSION_INSTALLED=$(node --version)
NPM_VERSION_INSTALLED=$(npm --version)

print_success "Node.js instalado: $NODE_VERSION_INSTALLED"
print_success "NPM instalado: $NPM_VERSION_INSTALLED"

# Instalar PM2 globalmente
print_info "Instalando PM2 (gerenciador de processos)..."
npm install -g pm2

print_success "PM2 instalado: $(pm2 --version)"

#===============================================================================
# CRIAÇÃO DO USUÁRIO DO SISTEMA
#===============================================================================

print_step "CRIANDO USUÁRIO DO SISTEMA"

# Criar usuário se não existir
if ! id "$SERVICE_USER" &>/dev/null; then
    print_info "Criando usuário $SERVICE_USER..."
    useradd --system --home-dir "$INSTALL_DIR" --shell /bin/bash --create-home "$SERVICE_USER"
    print_success "Usuário $SERVICE_USER criado"
else
    print_warning "Usuário $SERVICE_USER já existe"
fi

# Adicionar ao grupo sudo (opcional, para manutenção)
usermod -aG sudo "$SERVICE_USER" 2>/dev/null || true

#===============================================================================
# CLONE DO REPOSITÓRIO
#===============================================================================

print_step "CLONANDO REPOSITÓRIO DO GITHUB"

# Remover diretório se existir
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Diretório $INSTALL_DIR já existe. Fazendo backup..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Clonar repositório
print_info "Clonando $GITHUB_REPO..."
git clone "$GITHUB_REPO" "$INSTALL_DIR"

# Alterar proprietário
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

print_success "Repositório clonado em $INSTALL_DIR"

#===============================================================================
# INSTALAÇÃO DAS DEPENDÊNCIAS DO PROJETO
#===============================================================================

print_step "INSTALANDO DEPENDÊNCIAS DO PROJETO"

cd "$INSTALL_DIR"

# Instalar dependências como usuário timepulse
print_info "Instalando dependências do Node.js..."
sudo -u "$SERVICE_USER" npm install

# Build do projeto
print_info "Fazendo build do projeto..."
sudo -u "$SERVICE_USER" npm run build

print_success "Dependências instaladas e projeto buildado"

#===============================================================================
# CONFIGURAÇÃO DO ARQUIVO .env
#===============================================================================

print_step "CONFIGURANDO ARQUIVO DE AMBIENTE"

# Criar arquivo .env baseado no .env.example
if [ -f ".env.example" ]; then
    print_info "Criando arquivo .env baseado no .env.example..."
    sudo -u "$SERVICE_USER" cp .env.example .env
    
    print_warning "IMPORTANTE: Você precisa editar o arquivo .env com suas configurações:"
    print_info "  - Credenciais do Supabase"
    print_info "  - Configurações do iFood (opcional)"
    print_info "  - Configurações do WhatsApp (opcional)"
    
else
    print_info "Criando arquivo .env básico..."
    cat > .env << EOF
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

# ================================
# CONFIGURAÇÕES OPCIONAIS (FASE 2)
# ================================

# iFood Integration (opcional)
# IFOOD_CLIENT_ID=your_client_id_here
# IFOOD_CLIENT_SECRET=your_client_secret_here
# IFOOD_MERCHANT_ID=your_merchant_id_here
# IFOOD_ENVIRONMENT=production
# IFOOD_WEBHOOK_SECRET=your_webhook_secret
# IFOOD_WEBHOOK_URL=https://seu-dominio.com/api/ifood/webhook

# WhatsApp Integration (opcional)
# N8N_WEBHOOK_URL=sua_url_n8n
# EVOLUTION_API_URL=sua_url_evolution
# EVOLUTION_API_KEY=sua_chave
# OPENAI_API_KEY=sua_chave_chatgpt
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" .env
fi

print_success "Arquivo .env criado"

#===============================================================================
# CONFIGURAÇÃO DO NGINX
#===============================================================================

print_step "CONFIGURANDO NGINX"

# Backup da configuração padrão
if [ -f "/etc/nginx/sites-available/default" ]; then
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
fi

# Criar configuração do TimePulse
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

    # Arquivos estáticos (se necessário)
    location /static/ {
        alias /opt/timepulse/dist/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
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

# Testar configuração
nginx -t

# Recarregar nginx
systemctl reload nginx

print_success "Nginx configurado"

#===============================================================================
# CONFIGURAÇÃO DO PM2
#===============================================================================

print_step "CONFIGURANDO PM2"

# Criar arquivo de configuração do PM2
cat > "$INSTALL_DIR/ecosystem.config.js" << 'EOF'
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
    watch: false,
    ignore_watch: ['node_modules', 'logs', '*.log']
  }]
};
EOF

chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/ecosystem.config.js"

# Criar diretório de logs
mkdir -p /var/log/timepulse
chown "$SERVICE_USER:$SERVICE_USER" /var/log/timepulse

# Configurar PM2 para iniciar com o sistema
sudo -u "$SERVICE_USER" bash -c "cd $INSTALL_DIR && pm2 start ecosystem.config.js"
sudo -u "$SERVICE_USER" pm2 save
sudo -u "$SERVICE_USER" pm2 startup systemd -u "$SERVICE_USER" --hp "$INSTALL_DIR"

# Executar comando gerado pelo PM2 startup
PM2_STARTUP_CMD=$(sudo -u "$SERVICE_USER" pm2 startup systemd -u "$SERVICE_USER" --hp "$INSTALL_DIR" | tail -n 1)
eval "$PM2_STARTUP_CMD" 2>/dev/null || true

print_success "PM2 configurado e aplicação iniciada"

#===============================================================================
# CONFIGURAÇÃO DO FIREWALL
#===============================================================================

print_step "CONFIGURANDO FIREWALL"

# Resetar UFW
ufw --force reset

# Políticas padrão
ufw default deny incoming
ufw default allow outgoing

# Permitir SSH
ufw allow ssh

# Permitir HTTP e HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Permitir porta da aplicação (apenas local)
ufw allow from 127.0.0.1 to any port 3000

# Habilitar firewall
ufw --force enable

print_success "Firewall configurado"

#===============================================================================
# CONFIGURAÇÃO DO FAIL2BAN
#===============================================================================

print_step "CONFIGURANDO FAIL2BAN"

# Configuração básica para SSH e Nginx
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
EOF

systemctl restart fail2ban

print_success "Fail2ban configurado"

#===============================================================================
# CONFIGURAÇÃO DE LOGS ROTATIVOS
#===============================================================================

print_step "CONFIGURANDO ROTAÇÃO DE LOGS"

cat > /etc/logrotate.d/timepulse << 'EOF'
/var/log/timepulse/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 timepulse timepulse
    postrotate
        sudo -u timepulse pm2 reload timepulse-delivery
    endscript
}

/var/log/nginx/timepulse.*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx
    endscript
}
EOF

print_success "Rotação de logs configurada"

#===============================================================================
# INSTALAÇÃO DE FERRAMENTAS DE MONITORAMENTO
#===============================================================================

print_step "INSTALANDO FERRAMENTAS DE MONITORAMENTO"

# Instalar htop, iotop, etc.
apt-get install -y -qq htop iotop nethogs ncdu tree

# Instalar e configurar Supervisor (backup do PM2)
cat > /etc/supervisor/conf.d/timepulse.conf << EOF
[program:timepulse]
command=/usr/bin/node dist/index.js
directory=$INSTALL_DIR
user=$SERVICE_USER
autostart=false
autorestart=false
redirect_stderr=true
stdout_logfile=/var/log/timepulse/supervisor.log
environment=NODE_ENV=production
EOF

supervisorctl reread
supervisorctl update

print_success "Ferramentas de monitoramento instaladas"

#===============================================================================
# CONFIGURAÇÃO DE BACKUP AUTOMÁTICO
#===============================================================================

print_step "CONFIGURANDO BACKUP AUTOMÁTICO"

# Criar script de backup
cat > /usr/local/bin/timepulse-backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/backups/timepulse"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/timepulse_backup_$DATE.tar.gz"

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Fazer backup do projeto (excluindo node_modules)
tar -czf "$BACKUP_FILE" \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='*.log' \
    -C /opt timepulse

# Manter apenas os últimos 7 backups
find "$BACKUP_DIR" -name "timepulse_backup_*.tar.gz" -mtime +7 -delete

echo "Backup criado: $BACKUP_FILE"
EOF

chmod +x /usr/local/bin/timepulse-backup.sh

# Adicionar ao crontab (backup diário às 2h da manhã)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/timepulse-backup.sh") | crontab -

print_success "Backup automático configurado"

#===============================================================================
# VERIFICAÇÕES FINAIS E TESTES
#===============================================================================

print_step "VERIFICAÇÕES FINAIS"

# Verificar se o serviço está rodando
sleep 5

if sudo -u "$SERVICE_USER" pm2 list | grep -q "timepulse-delivery"; then
    print_success "Aplicação está rodando no PM2"
else
    print_error "Aplicação não está rodando no PM2"
fi

# Verificar se o Nginx está funcionando
if systemctl is-active --quiet nginx; then
    print_success "Nginx está funcionando"
else
    print_error "Nginx não está funcionando"
fi

# Testar conectividade
if curl -s http://localhost > /dev/null; then
    print_success "Aplicação respondendo na porta 80"
else
    print_warning "Aplicação não está respondendo na porta 80"
fi

#===============================================================================
# INFORMAÇÕES FINAIS
#===============================================================================

print_step "INSTALAÇÃO CONCLUÍDA"

echo ""
echo -e "${GREEN}🎉 INSTALAÇÃO DO TIMEPULSE DELIVERY CONCLUÍDA COM SUCESSO! 🎉${NC}"
echo ""
echo -e "${CYAN}📋 INFORMAÇÕES IMPORTANTES:${NC}"
echo ""
echo -e "${YELLOW}📁 Localização do projeto:${NC} $INSTALL_DIR"
echo -e "${YELLOW}👤 Usuário do sistema:${NC} $SERVICE_USER"
echo -e "${YELLOW}🌐 URL de acesso:${NC} http://$(hostname -I | awk '{print $1}')"
echo -e "${YELLOW}📊 Monitoramento PM2:${NC} sudo -u $SERVICE_USER pm2 monit"
echo -e "${YELLOW}📝 Logs da aplicação:${NC} sudo -u $SERVICE_USER pm2 logs"
echo -e "${YELLOW}🔧 Configuração:${NC} $INSTALL_DIR/.env"
echo ""
echo -e "${RED}⚠️  PRÓXIMOS PASSOS OBRIGATÓRIOS:${NC}"
echo ""
echo -e "${YELLOW}1.${NC} Editar arquivo de configuração:"
echo -e "   ${CYAN}sudo nano $INSTALL_DIR/.env${NC}"
echo ""
echo -e "${YELLOW}2.${NC} Configurar credenciais do Supabase no arquivo .env"
echo ""
echo -e "${YELLOW}3.${NC} Executar script SQL no Supabase:"
echo -e "   ${CYAN}$INSTALL_DIR/setup-database.sql${NC}"
echo ""
echo -e "${YELLOW}4.${NC} Reiniciar aplicação após configuração:"
echo -e "   ${CYAN}sudo -u $SERVICE_USER pm2 restart timepulse-delivery${NC}"
echo ""
echo -e "${YELLOW}5.${NC} Para SSL/HTTPS, instale e configure Certbot:"
echo -e "   ${CYAN}apt install certbot python3-certbot-nginx${NC}"
echo -e "   ${CYAN}certbot --nginx -d seu-dominio.com${NC}"
echo ""
echo -e "${CYAN}🛠️  COMANDOS ÚTEIS:${NC}"
echo ""
echo -e "${YELLOW}• Status da aplicação:${NC} sudo -u $SERVICE_USER pm2 status"
echo -e "${YELLOW}• Reiniciar aplicação:${NC} sudo -u $SERVICE_USER pm2 restart timepulse-delivery"
echo -e "${YELLOW}• Ver logs:${NC} sudo -u $SERVICE_USER pm2 logs timepulse-delivery"
echo -e "${YELLOW}• Monitorar recursos:${NC} sudo -u $SERVICE_USER pm2 monit"
echo -e "${YELLOW}• Status do Nginx:${NC} systemctl status nginx"
echo -e "${YELLOW}• Testar configuração Nginx:${NC} nginx -t"
echo ""
echo -e "${GREEN}✅ Sistema pronto para uso após configuração do Supabase!${NC}"
echo ""

#===============================================================================
# SCRIPT DE PÓS-INSTALAÇÃO
#===============================================================================

# Criar script para facilitar manutenção
cat > /usr/local/bin/timepulse-admin << 'EOF'
#!/bin/bash

# TimePulse Admin - Script de administração

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
    update)
        echo "Atualizando TimePulse Delivery..."
        cd "$INSTALL_DIR"
        sudo -u "$SERVICE_USER" git pull
        sudo -u "$SERVICE_USER" npm install
        sudo -u "$SERVICE_USER" npm run build
        sudo -u "$SERVICE_USER" pm2 restart timepulse-delivery
        echo "Atualização concluída!"
        ;;
    backup)
        /usr/local/bin/timepulse-backup.sh
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|monitor|update|backup}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/timepulse-admin

print_info "Script de administração criado: timepulse-admin"
print_info "Uso: timepulse-admin {start|stop|restart|status|logs|monitor|update|backup}"

echo ""
echo -e "${PURPLE}🔗 Para suporte e documentação:${NC}"
echo -e "${CYAN}   https://github.com/luishplleite/TimePulseDelivery${NC}"
echo ""

exit 0
