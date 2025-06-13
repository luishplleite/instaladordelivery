#!/bin/bash

#===============================================================================
# TimePulse Delivery - Script de Configuração Pós-Instalação
#===============================================================================
# 
# Execute este script APÓS configurar as credenciais do Supabase no arquivo .env
# Este script automatiza a configuração inicial do banco de dados e testes
#
# Uso: sudo bash post-install-config.sh
#
#===============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
INSTALL_DIR="/opt/timepulse"
SERVICE_USER="timepulse"

#===============================================================================
# FUNÇÕES AUXILIARES
#===============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}=============================================================================${NC}"
    echo -e "${CYAN}            TIMEPULSE DELIVERY - CONFIGURAÇÃO PÓS-INSTALAÇÃO${NC}"
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

#===============================================================================
# VERIFICAÇÕES INICIAIS
#===============================================================================

print_header
check_root

cd "$INSTALL_DIR"

print_step "VERIFICANDO CONFIGURAÇÃO"

# Verificar se arquivo .env existe
if [ ! -f ".env" ]; then
    print_error "Arquivo .env não encontrado. Execute primeiro o script de instalação."
    exit 1
fi

# Verificar se credenciais do Supabase estão configuradas
if grep -q "sua-url-do-supabase" .env || grep -q "sua_chave_publica_aqui" .env; then
    print_error "Credenciais do Supabase ainda não foram configuradas no arquivo .env"
    print_info "Edite o arquivo $INSTALL_DIR/.env com suas credenciais antes de continuar"
    exit 1
fi

print_success "Arquivo .env configurado"

#===============================================================================
# COLETA DE INFORMAÇÕES
#===============================================================================

print_step "CONFIGURAÇÃO INTERATIVA"

# Solicitar configurações adicionais
echo -e "${CYAN}📝 Vamos configurar algumas opções adicionais:${NC}"
echo ""

# Domínio/IP
read -p "🌐 Qual domínio ou IP será usado para acessar o sistema? (ex: localhost, 192.168.1.100, meudominio.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    DOMAIN="localhost"
fi

# Porta personalizada
read -p "🔌 Qual porta usar para a aplicação? (padrão: 3000): " APP_PORT
if [ -z "$APP_PORT" ]; then
    APP_PORT="3000"
fi

# SSL/HTTPS
read -p "🔒 Deseja configurar SSL/HTTPS automaticamente? (s/N): " SETUP_SSL
SETUP_SSL=${SETUP_SSL,,}

# Email para SSL (se necessário)
if [[ "$SETUP_SSL" == "s" || "$SETUP_SSL" == "sim" ]]; then
    read -p "📧 Digite seu email para o certificado SSL: " SSL_EMAIL
    if [ -z "$SSL_EMAIL" ]; then
        print_warning "Email não fornecido. SSL será configurado manualmente depois."
        SETUP_SSL="n"
    fi
fi

# Backup automático
read -p "💾 Configurar backup automático diário? (S/n): " SETUP_BACKUP
SETUP_BACKUP=${SETUP_BACKUP,,}
if [[ "$SETUP_BACKUP" != "n" && "$SETUP_BACKUP" != "nao" ]]; then
    SETUP_BACKUP="s"
fi

#===============================================================================
# ATUALIZAÇÃO DA CONFIGURAÇÃO
#===============================================================================

print_step "ATUALIZANDO CONFIGURAÇÕES"

# Atualizar porta no .env se diferente de 3000
if [ "$APP_PORT" != "3000" ]; then
    print_info "Atualizando porta da aplicação para $APP_PORT..."
    sed -i "s/PORT=3000/PORT=$APP_PORT/g" .env
    
    # Atualizar configuração do PM2
    sed -i "s/PORT: 3000/PORT: $APP_PORT/g" ecosystem.config.js
    
    # Atualizar configuração do Nginx
    sed -i "s/proxy_pass http:\/\/localhost:3000/proxy_pass http:\/\/localhost:$APP_PORT/g" /etc/nginx/sites-available/timepulse
fi

# Atualizar server_name no Nginx
if [ "$DOMAIN" != "localhost" ]; then
    print_info "Configurando domínio $DOMAIN no Nginx..."
    sed -i "s/server_name localhost/server_name $DOMAIN/g" /etc/nginx/sites-available/timepulse
fi

print_success "Configurações atualizadas"

#===============================================================================
# CONFIGURAÇÃO DO SSL/HTTPS
#===============================================================================

if [[ "$SETUP_SSL" == "s" ]]; then
    print_step "CONFIGURANDO SSL/HTTPS"
    
    # Instalar Certbot
    print_info "Instalando Certbot..."
    apt-get update -qq
    apt-get install -y -qq certbot python3-certbot-nginx
    
    # Recarregar Nginx antes do SSL
    nginx -t && systemctl reload nginx
    
    # Obter certificado SSL
    print_info "Obtendo certificado SSL para $DOMAIN..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect; then
        print_success "SSL configurado com sucesso"
        
        # Configurar renovação automática
        print_info "Configurando renovação automática do SSL..."
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
    else
        print_warning "Falha ao configurar SSL. Verifique se o domínio está apontando corretamente."
    fi
fi

#===============================================================================
# CONFIGURAÇÃO DE FIREWALL AVANÇADO
#===============================================================================

print_step "CONFIGURANDO FIREWALL AVANÇADO"

# Permitir porta personalizada se diferente de 80/443
if [ "$APP_PORT" != "80" ] && [ "$APP_PORT" != "443" ] && [ "$APP_PORT" != "3000" ]; then
    print_info "Permitindo porta $APP_PORT no firewall..."
    ufw allow from 127.0.0.1 to any port "$APP_PORT"
fi

# Configuração adicional de segurança
print_info "Aplicando configurações de segurança..."

# Limitar tentativas de conexão SSH
ufw limit ssh

# Permitir apenas conexões estabelecidas
ufw allow out on any to any port 53  # DNS
ufw allow out on any to any port 80  # HTTP
ufw allow out on any to any port 443 # HTTPS
ufw allow out on any to any port 123 # NTP

systemctl restart ufw

print_success "Firewall configurado"

#===============================================================================
# TESTE DA APLICAÇÃO
#===============================================================================

print_step "TESTANDO APLICAÇÃO"

# Reiniciar aplicação com novas configurações
print_info "Reiniciando aplicação..."
sudo -u "$SERVICE_USER" pm2 restart timepulse-delivery

# Aguardar inicialização
print_info "Aguardando inicialização..."
sleep 10

# Testar se aplicação está respondendo
if sudo -u "$SERVICE_USER" pm2 list | grep -q "online"; then
    print_success "Aplicação está online no PM2"
else
    print_error "Aplicação não está online no PM2"
    print_info "Verificando logs..."
    sudo -u "$SERVICE_USER" pm2 logs timepulse-delivery --lines 10
fi

# Testar conectividade HTTP
print_info "Testando conectividade HTTP..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:"$APP_PORT" | grep -q "200\|404"; then
    print_success "Aplicação respondendo na porta $APP_PORT"
else
    print_warning "Aplicação pode não estar respondendo corretamente"
fi

# Testar Nginx
print_info "Testando Nginx..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|404"; then
    print_success "Nginx está funcionando"
else
    print_warning "Nginx pode ter problemas"
fi

#===============================================================================
# CONFIGURAÇÃO DE MONITORAMENTO
#===============================================================================

print_step "CONFIGURANDO MONITORAMENTO"

# Criar script de health check
cat > /usr/local/bin/timepulse-healthcheck << EOF
#!/bin/bash

# Health check para TimePulse Delivery

check_app() {
    if ! sudo -u "$SERVICE_USER" pm2 list | grep -q "timepulse-delivery.*online"; then
        echo "CRITICAL: Aplicação não está online"
        return 1
    fi
    
    if ! curl -s http://localhost:$APP_PORT > /dev/null; then
        echo "CRITICAL: Aplicação não está respondendo"
        return 1
    fi
    
    echo "OK: Aplicação funcionando normalmente"
    return 0
}

check_nginx() {
    if ! systemctl is-active --quiet nginx; then
        echo "CRITICAL: Nginx não está funcionando"
        return 1
    fi
    
    echo "OK: Nginx funcionando normalmente"
    return 0
}

check_disk() {
    DISK_USAGE=\$(df /opt | tail -1 | awk '{print \$5}' | sed 's/%//')
    if [ "\$DISK_USAGE" -gt 90 ]; then
        echo "WARNING: Disco com \$DISK_USAGE% de uso"
        return 1
    fi
    
    echo "OK: Disco com \$DISK_USAGE% de uso"
    return 0
}

check_memory() {
    MEM_USAGE=\$(free | grep Mem | awk '{printf "%.0f", \$3/\$2 * 100.0}')
    if [ "\$MEM_USAGE" -gt 90 ]; then
        echo "WARNING: Memória com \$MEM_USAGE% de uso"
        return 1
    fi
    
    echo "OK: Memória com \$MEM_USAGE% de uso"
    return 0
}

# Executar checks
echo "TimePulse Health Check - \$(date)"
echo "======================================"

check_app
check_nginx  
check_disk
check_memory

echo ""
EOF

chmod +x /usr/local/bin/timepulse-healthcheck

# Configurar cron para health check (a cada 5 minutos)
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/timepulse-healthcheck >> /var/log/timepulse/healthcheck.log 2>&1") | crontab -

print_success "Monitoramento configurado"

#===============================================================================
# CONFIGURAÇÃO DE BACKUP
#===============================================================================

if [[ "$SETUP_BACKUP" == "s" ]]; then
    print_step "CONFIGURANDO BACKUP AUTOMÁTICO"
    
    # Criar script de backup melhorado
    cat > /usr/local/bin/timepulse-backup-advanced << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/backups/timepulse"
DATE=$(date +%Y%m%d_%H%M%S)
INSTALL_DIR="/opt/timepulse"

# Criar diretórios
mkdir -p "$BACKUP_DIR"/{app,configs,logs}

# Backup da aplicação
echo "Fazendo backup da aplicação..."
tar -czf "$BACKUP_DIR/app/app_$DATE.tar.gz" \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='*.log' \
    -C /opt timepulse

# Backup das configurações
echo "Fazendo backup das configurações..."
cp /etc/nginx/sites-available/timepulse "$BACKUP_DIR/configs/nginx_$DATE.conf"
cp "$INSTALL_DIR/.env" "$BACKUP_DIR/configs/env_$DATE"
cp "$INSTALL_DIR/ecosystem.config.js" "$BACKUP_DIR/configs/pm2_$DATE.js"

# Backup dos logs importantes
echo "Fazendo backup dos logs..."
tar -czf "$BACKUP_DIR/logs/logs_$DATE.tar.gz" /var/log/timepulse/ 2>/dev/null || true

# Limpeza de backups antigos (manter 30 dias)
find "$BACKUP_DIR" -type f -mtime +30 -delete

# Relatório
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Backup concluído em $BACKUP_DIR"
echo "Tamanho total dos backups: $TOTAL_SIZE"

# Log
echo "$(date): Backup realizado com sucesso" >> /var/log/timepulse/backup.log
EOF

    chmod +x /usr/local/bin/timepulse-backup-advanced
    
    # Configurar backup diário às 3h
    (crontab -l 2>/dev/null | grep -v timepulse-backup; echo "0 3 * * * /usr/local/bin/timepulse-backup-advanced") | crontab -
    
    print_success "Backup automático configurado (diário às 3h)"
fi

#===============================================================================
# OTIMIZAÇÕES DO SISTEMA
#===============================================================================

print_step "APLICANDO OTIMIZAÇÕES"

# Otimizações do Node.js
print_info "Configurando otimizações do Node.js..."
echo 'export NODE_OPTIONS="--max-old-space-size=512"' >> /home/$SERVICE_USER/.bashrc

# Otimizações do sistema
print_info "Aplicando otimizações do sistema..."

# Aumentar limites de arquivo
cat > /etc/security/limits.d/timepulse.conf << EOF
$SERVICE_USER soft nofile 65536
$SERVICE_USER hard nofile 65536
$SERVICE_USER soft nproc 32768
$SERVICE_USER hard nproc 32768
EOF

# Otimizações de rede
cat > /etc/sysctl.d/99-timepulse.conf << EOF
# Otimizações para aplicação web
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
EOF

sysctl -p /etc/sysctl.d/99-timepulse.conf

print_success "Otimizações aplicadas"

#===============================================================================
# RELATÓRIO FINAL
#===============================================================================

print_step "CONFIGURAÇÃO CONCLUÍDA"

echo ""
echo -e "${GREEN}🎉 CONFIGURAÇÃO PÓS-INSTALAÇÃO CONCLUÍDA! 🎉${NC}"
echo ""
echo -e "${CYAN}📊 RESUMO DA CONFIGURAÇÃO:${NC}"
echo ""
echo -e "${YELLOW}🌐 Domínio/IP:${NC} $DOMAIN"
echo -e "${YELLOW}🔌 Porta da aplicação:${NC} $APP_PORT"
echo -e "${YELLOW}🔒 SSL/HTTPS:${NC} $([ "$SETUP_SSL" == "s" ] && echo "Configurado" || echo "Não configurado")"
echo -e "${YELLOW}💾 Backup automático:${NC} $([ "$SETUP_BACKUP" == "s" ] && echo "Ativado" || echo "Desativado")"
echo ""
echo -e "${CYAN}🔗 URLs DE ACESSO:${NC}"
echo ""
if [[ "$SETUP_SSL" == "s" ]]; then
    echo -e "${GREEN}🔒 HTTPS (Seguro):${NC} https://$DOMAIN"
fi
echo -e "${YELLOW}🌐 HTTP:${NC} http://$DOMAIN"
echo ""
echo -e "${CYAN}🛠️  COMANDOS DE ADMINISTRAÇÃO:${NC}"
echo ""
echo -e "${YELLOW}• Status geral:${NC} timepulse-admin status"
echo -e "${YELLOW}• Reiniciar:${NC} timepulse-admin restart"
echo -e "${YELLOW}• Ver logs:${NC} timepulse-admin logs"
echo -e "${YELLOW}• Monitorar:${NC} timepulse-admin monitor"
echo -e "${YELLOW}• Atualizar:${NC} timepulse-admin update"
echo -e "${YELLOW}• Health check:${NC} timepulse-healthcheck"
echo ""
echo -e "${CYAN}📋 PRÓXIMOS PASSOS:${NC}"
echo ""
echo -e "${YELLOW}1.${NC} Acesse o sistema via navegador"
echo -e "${YELLOW}2.${NC} Execute o script SQL do banco no Supabase:"
echo -e "   ${CYAN}$INSTALL_DIR/setup-database.sql${NC}"
echo -e "${YELLOW}3.${NC} Faça login com: admin@timepulse.com / 123456"
echo -e "${YELLOW}4.${NC} Configure produtos e usuários"
echo -e "${YELLOW}5.${NC} Teste o sistema de tempo real"
echo ""
echo -e "${GREEN}✅ Sistema totalmente configurado e pronto para uso!${NC}"
echo ""

# Executar health check final
print_info "Executando verificação final..."
/usr/local/bin/timepulse-healthcheck

exit 0
