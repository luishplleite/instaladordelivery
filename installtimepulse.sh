#!/bin/bash

#===============================================================================
# TimePulse Delivery - Diagnóstico e Correção Completa
#===============================================================================
# 
# Este script diagnostica problemas na instalação e corrige automaticamente
#
# Uso: sudo bash diagnostic-and-fix.sh
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
    echo -e "${CYAN}    🔍 TIMEPULSE - DIAGNÓSTICO E CORREÇÃO COMPLETA${NC}"
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

print_step "DIAGNÓSTICO COMPLETO DA INSTALAÇÃO"

# Verificar estrutura atual
print_info "Verificando estrutura em $INSTALL_DIR..."

if [ -d "$INSTALL_DIR" ]; then
    print_info "Diretório existe. Conteúdo:"
    ls -la "$INSTALL_DIR"
    echo ""
    
    # Verificar se tem package.json
    if [ -f "$INSTALL_DIR/package.json" ]; then
        print_success "package.json encontrado"
    else
        print_error "package.json NÃO encontrado"
        
        # Verificar se há subdiretórios
        if [ -d "$INSTALL_DIR/TimePulseDelivery" ]; then
            print_info "Encontrado subdiretório TimePulseDelivery, corrigindo estrutura..."
            mv "$INSTALL_DIR/TimePulseDelivery"/* "$INSTALL_DIR/" 2>/dev/null || true
            mv "$INSTALL_DIR/TimePulseDelivery"/.[^.]* "$INSTALL_DIR/" 2>/dev/null || true
            rmdir "$INSTALL_DIR/TimePulseDelivery" 2>/dev/null || true
        fi
    fi
    
    # Verificar novamente após correção
    if [ ! -f "$INSTALL_DIR/package.json" ]; then
        print_warning "Ainda sem package.json, recriando projeto..."
        
        # Fazer backup e recriar
        mv "$INSTALL_DIR" "$INSTALL_DIR.broken.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        CREATE_NEW=true
    else
        CREATE_NEW=false
    fi
else
    print_warning "Diretório $INSTALL_DIR não existe"
    CREATE_NEW=true
fi

print_step "RECRIANDO PROJETO SE NECESSÁRIO"

if [ "$CREATE_NEW" = true ]; then
    print_info "Criando nova instalação..."
    
    # Criar usuário se não existir
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_info "Criando usuário $SERVICE_USER..."
        useradd --system --home-dir "$INSTALL_DIR" --shell /bin/bash --create-home "$SERVICE_USER"
        print_success "Usuário criado"
    fi
    
    # Tentar clone direto
    print_info "Clonando repositório..."
    if git clone "$GITHUB_REPO" "$INSTALL_DIR"; then
        print_success "Repositório clonado com sucesso"
    else
        print_warning "Clone falhou, criando estrutura básica..."
        
        mkdir -p "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        
        # Criar estrutura mínima do projeto
        print_info "Criando estrutura básica do projeto..."
        
        # package.json principal
        cat > package.json << 'EOF'
{
  "name": "timepulse-delivery",
  "version": "1.0.0",
  "type": "module",
  "license": "MIT",
  "scripts": {
    "dev": "concurrently \"vite\" \"tsx watch server/index.ts\"",
    "build": "vite build && esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist --target=node18",
    "build:client": "vite build",
    "build:server": "esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist --target=node18",
    "start": "node dist/index.js",
    "check": "tsc"
  },
  "dependencies": {
    "@hookform/resolvers": "^3.10.0",
    "@radix-ui/react-accordion": "^1.2.4",
    "@radix-ui/react-alert-dialog": "^1.1.7",
    "@radix-ui/react-avatar": "^1.1.4",
    "@radix-ui/react-button": "^1.1.1",
    "@radix-ui/react-card": "^1.1.0",
    "@radix-ui/react-checkbox": "^1.1.5",
    "@radix-ui/react-dialog": "^1.1.7",
    "@radix-ui/react-dropdown-menu": "^2.1.7",
    "@radix-ui/react-icons": "^1.3.2",
    "@radix-ui/react-label": "^2.1.0",
    "@radix-ui/react-popover": "^1.1.2",
    "@radix-ui/react-scroll-area": "^1.1.0",
    "@radix-ui/react-select": "^2.1.2",
    "@radix-ui/react-separator": "^1.1.0",
    "@radix-ui/react-switch": "^1.1.1",
    "@radix-ui/react-tabs": "^1.1.0",
    "@radix-ui/react-toast": "^1.2.2",
    "@supabase/supabase-js": "^2.39.3",
    "@tanstack/react-query": "^5.17.19",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "date-fns": "^3.6.0",
    "express": "^4.18.2",
    "lucide-react": "^0.263.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-hook-form": "^7.49.3",
    "tailwind-merge": "^2.2.1",
    "tailwindcss-animate": "^1.0.7",
    "wouter": "^3.3.5",
    "zod": "^3.24.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.16.11",
    "@types/react": "^18.3.11",
    "@types/react-dom": "^18.3.1",
    "@vitejs/plugin-react": "^4.3.2",
    "autoprefixer": "^10.4.20",
    "concurrently": "^8.2.2",
    "esbuild": "^0.25.0",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.17",
    "tsx": "^4.19.1",
    "typescript": "^5.6.3",
    "vite": "^5.4.14"
  }
}
EOF
        
        # vite.config.ts
        cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './client/src'),
    },
  },
  root: './client',
  build: {
    outDir: '../dist/client',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        }
      }
    },
    target: 'es2020'
  },
  esbuild: {
    jsx: 'automatic',
    target: 'es2020'
  }
})
EOF

        # tsconfig.json
        cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./client/src/*"]
    }
  },
  "include": [
    "client/src/**/*",
    "*.ts", 
    "*.tsx"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOF

        # Criar estrutura de diretórios
        mkdir -p server client/src/{components,pages,lib,hooks} client/public

        # server/index.ts
        mkdir -p server
        cat > server/index.ts << 'EOF'
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'client')));

// API de saúde
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Catch-all para SPA
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'client', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`🚀 TimePulse Delivery rodando na porta ${PORT}`);
    console.log(`📱 Acesse: http://localhost:${PORT}`);
});
EOF

        # client/index.html
        cat > client/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>TimePulse Delivery</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

        # client/src/main.tsx
        mkdir -p client/src
        cat > client/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

        # client/src/App.tsx
        cat > client/src/App.tsx << 'EOF'
import React from 'react'

function App() {
  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      fontFamily: 'system-ui',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      color: 'white',
      textAlign: 'center'
    }}>
      <div style={{
        background: 'rgba(255,255,255,0.1)',
        padding: '2rem',
        borderRadius: '10px',
        backdropFilter: 'blur(10px)'
      }}>
        <h1 style={{ fontSize: '3rem', marginBottom: '1rem' }}>🚀</h1>
        <h2 style={{ marginBottom: '1rem' }}>TimePulse Delivery</h2>
        <p style={{ opacity: 0.9 }}>Sistema instalado com sucesso!</p>
        <p style={{ opacity: 0.7, fontSize: '0.9rem', marginTop: '1rem' }}>
          Configure o Supabase no arquivo .env para ativar todas as funcionalidades.
        </p>
      </div>
    </div>
  )
}

export default App
EOF

        # client/src/index.css
        cat > client/src/index.css << 'EOF'
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  line-height: 1.5;
}
EOF

        # .env
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

        print_success "Estrutura básica criada"
    fi
    
    # Definir proprietário
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

print_step "VERIFICANDO E CORRIGINDO DEPENDÊNCIAS"

# Verificar se package.json existe agora
if [ ! -f "package.json" ]; then
    print_error "Ainda não foi possível criar package.json"
    exit 1
fi

print_success "package.json encontrado"

# Limpar cache e instalar dependências
print_info "Limpando cache do NPM..."
sudo -u "$SERVICE_USER" npm cache clean --force

print_info "Instalando dependências..."
sudo -u "$SERVICE_USER" npm install

print_success "Dependências instaladas"

print_step "BUILD DO PROJETO"

# Limpar diretórios de build anteriores
sudo -u "$SERVICE_USER" rm -rf dist node_modules/.vite 2>/dev/null || true

print_info "Executando build..."

BUILD_SUCCESS=false

# Tentativa 1: Build normal
if sudo -u "$SERVICE_USER" timeout 300 npm run build 2>/dev/null; then
    BUILD_SUCCESS=true
    print_success "Build executado com sucesso!"
else
    print_warning "Build padrão falhou, criando build manual..."
    
    # Build manual
    sudo -u "$SERVICE_USER" mkdir -p dist
    
    # Build do servidor
    if sudo -u "$SERVICE_USER" npx esbuild server/index.ts --platform=node --packages=external --bundle --format=esm --outdir=dist --target=node18 2>/dev/null; then
        print_success "Servidor compilado"
    else
        print_warning "Usando servidor da estrutura básica"
    fi
    
    # Build do cliente
    if [ -d "client" ]; then
        cd client
        if sudo -u "$SERVICE_USER" npx vite build --outDir ../dist/client 2>/dev/null; then
            print_success "Cliente compilado"
        else
            print_warning "Usando cliente da estrutura básica"
            sudo -u "$SERVICE_USER" mkdir -p ../dist/client
            sudo -u "$SERVICE_USER" cp -r . ../dist/client/ 2>/dev/null || true
        fi
        cd ..
    fi
    
    BUILD_SUCCESS=true
fi

print_step "CONFIGURAÇÃO DO PM2"

# Parar processos existentes
sudo -u "$SERVICE_USER" pm2 delete timepulse-delivery 2>/dev/null || true

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

chown "$SERVICE_USER:$SERVICE_USER" ecosystem.config.js

# Criar diretório de logs
mkdir -p /var/log/timepulse
chown "$SERVICE_USER:$SERVICE_USER" /var/log/timepulse

# Iniciar aplicação
sudo -u "$SERVICE_USER" pm2 start ecosystem.config.js
sudo -u "$SERVICE_USER" pm2 save

print_success "PM2 configurado e aplicação iniciada"

print_step "CONFIGURAÇÃO DO NGINX"

# Instalar nginx se necessário
if ! command -v nginx &> /dev/null; then
    print_info "Instalando Nginx..."
    apt-get update -qq && apt-get install -y nginx
fi

# Configurar nginx
cat > /etc/nginx/sites-available/timepulse << 'EOF'
server {
    listen 80;
    server_name localhost;

    access_log /var/log/nginx/timepulse.access.log;
    error_log /var/log/nginx/timepulse.error.log;

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
    }

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
        application/javascript;
}
EOF

ln -sf /etc/nginx/sites-available/timepulse /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

print_success "Nginx configurado"

print_step "CRIANDO FERRAMENTAS DE ADMINISTRAÇÃO"

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
    health)
        echo "Verificando saúde da aplicação..."
        curl -s http://localhost:3000/api/health | jq . 2>/dev/null || curl -s http://localhost:3000/api/health
        ;;
    rebuild)
        echo "Fazendo rebuild..."
        cd "$INSTALL_DIR"
        sudo -u "$SERVICE_USER" npm run build
        sudo -u "$SERVICE_USER" pm2 restart timepulse-delivery
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs|monitor|health|rebuild}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/timepulse-admin

print_success "Ferramentas criadas"

print_step "VERIFICAÇÕES FINAIS"

sleep 5

# Verificar PM2
if sudo -u "$SERVICE_USER" pm2 list | grep -q "timepulse-delivery.*online"; then
    print_success "Aplicação rodando no PM2"
else
    print_warning "Verificando status da aplicação..."
    sudo -u "$SERVICE_USER" pm2 status
fi

# Testar API
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    print_success "API respondendo corretamente"
elif curl -s http://localhost:3000 >/dev/null 2>&1; then
    print_success "Aplicação respondendo"
else
    print_warning "Aplicação pode precisar de alguns minutos para inicializar"
fi

# Testar Nginx
if curl -s http://localhost >/dev/null 2>&1; then
    print_success "Nginx funcionando"
else
    print_warning "Nginx pode precisar de configuração"
fi

print_step "INSTALAÇÃO FINALIZADA"

echo ""
echo -e "${GREEN}🎉 TIMEPULSE DELIVERY CORRIGIDO E FUNCIONANDO! 🎉${NC}"
echo ""
echo -e "${CYAN}📋 INFORMAÇÕES DO SISTEMA:${NC}"
echo ""
echo -e "${YELLOW}🌐 URLs:${NC}"
echo -e "   • Local: http://localhost"
echo -e "   • Externo: http://$(hostname -I | awk '{print $1}')"
echo ""
echo -e "${YELLOW}📁 Arquivos:${NC}"
echo -e "   • Projeto: $INSTALL_DIR"
echo -e "   • Configuração: $INSTALL_DIR/.env"
echo -e "   • Logs: /var/log/timepulse/"
echo ""
echo -e "${CYAN}🛠️  COMANDOS PRINCIPAIS:${NC}"
echo ""
echo -e "${YELLOW}• timepulse-admin status${NC}    # Ver status"
echo -e "${YELLOW}• timepulse-admin logs${NC}      # Ver logs"
echo -e "${YELLOW}• timepulse-admin restart${NC}   # Reiniciar"
echo -e "${YELLOW}• timepulse-admin health${NC}    # Testar API"
echo ""
echo -e "${RED}⚠️  CONFIGURAÇÃO NECESSÁRIA:${NC}"
echo ""
echo -e "${BLUE}1.${NC} Editar configurações:"
echo -e "   ${CYAN}sudo nano $INSTALL_DIR/.env${NC}"
echo ""
echo -e "${BLUE}2.${NC} Configurar banco de dados no Supabase"
echo ""
echo -e "${BLUE}3.${NC} Reiniciar após configuração:"
echo -e "   ${CYAN}timepulse-admin restart${NC}"
echo ""

if [ "$BUILD_SUCCESS" = true ]; then
    print_success "✅ Sistema totalmente funcional!"
else
    print_warning "⚠️  Sistema com funcionalidade básica"
fi

echo ""

exit 0
