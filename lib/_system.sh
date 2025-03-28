#!/bin/bash
# Script de automação para instalação e gerenciamento do Whaticket

#######################################
# Função utilitária para exibir banner
#######################################
print_banner() {
  clear
  echo "=============================="
  echo "      INSTALADOR WHATICKET    "
  echo "=============================="
}

#######################################
# Cria usuário 'deploy'
#######################################
system_create_user() {
  print_banner
  echo "💻 Criando usuário para a instância..."
  sleep 2

  sudo useradd -m -s /bin/bash -G sudo deploy
  echo "deploy:${deploy_password}" | sudo chpasswd
}

#######################################
# Cria pasta da instância
#######################################
system_create_folder() {
  print_banner
  echo "💻 Criando nova pasta da instância..."
  sleep 2

  sudo -u deploy mkdir -p "/home/deploy/${instancia_add}"
}

#######################################
# Move arquivos do projeto
#######################################
system_mv_folder() {
  print_banner
  echo "💻 Movendo arquivos do projeto..."
  sleep 2

  cp "${PROJECT_ROOT}/whaticket.zip" "/home/deploy/${instancia_add}/"
}

#######################################
# Descompacta o Whaticket
#######################################
system_unzip_whaticket() {
  print_banner
  echo "💻 Descompactando Whaticket..."
  sleep 2

  sudo -u deploy unzip "/home/deploy/${instancia_add}/whaticket.zip" -d "/home/deploy/${instancia_add}"
}

#######################################
# Atualiza sistema e instala dependências principais
#######################################
system_update() {
  print_banner
  echo "💻 Atualizando sistema..."
  sleep 2

  sudo apt-get update -y
  sudo apt-get install -y curl wget unzip gnupg lsb-release build-essential
}

#######################################
# Instala Node.js, PostgreSQL e ajusta timezone
#######################################
system_node_install() {
  print_banner
  echo "💻 Instalando Node.js e PostgreSQL..."
  sleep 2

  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  sudo npm install -g npm@latest

  echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
    sudo tee /etc/apt/sources.list.d/pgdg.list
  wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | sudo apt-key add -
  sudo apt-get update -y && sudo apt-get install -y postgresql

  sudo timedatectl set-timezone America/Sao_Paulo
}

#######################################
# Instala Docker e Redis
#######################################
system_docker_install() {
  print_banner
  echo "💻 Instalando Docker e Redis..."
  sleep 2

  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
}

#######################################
# Instala o PM2
#######################################
system_pm2_install() {
  print_banner
  echo "💻 Instalando PM2..."
  sleep 2

  sudo npm install -g pm2
}

#######################################
# Instala o Snapd e Certbot
#######################################
system_certbot_install() {
  print_banner
  echo "💻 Instalando Certbot..."
  sleep 2

  sudo apt install -y snapd
  sudo snap install core && sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
}

#######################################
# Instala e configura o NGINX
#######################################
system_nginx_install() {
  print_banner
  echo "💻 Instalando e configurando NGINX..."
  sleep 2

  sudo apt install -y nginx
  sudo rm -f /etc/nginx/sites-enabled/default
  echo 'client_max_body_size 100M;' | sudo tee /etc/nginx/conf.d/deploy.conf
  sudo systemctl restart nginx
}

#######################################
# Configura domínios e certificados SSL
#######################################
configurar_dominio() {
  print_banner
  echo "💻 Configurando domínios e certificados..."
  sleep 2

  backend_hostname=$(echo "${alter_backend_url/https:\/\//}")
  frontend_hostname=$(echo "${alter_frontend_url/https:\/\//}")

  sudo tee /etc/nginx/sites-available/${empresa_dominio}-backend > /dev/null <<EOF
server {
  server_name $backend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF

  sudo tee /etc/nginx/sites-available/${empresa_dominio}-frontend > /dev/null <<EOF
server {
  server_name $frontend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF

  sudo ln -sf /etc/nginx/sites-available/${empresa_dominio}-backend /etc/nginx/sites-enabled/
  sudo ln -sf /etc/nginx/sites-available/${empresa_dominio}-frontend /etc/nginx/sites-enabled/
  sudo systemctl restart nginx

  sudo certbot -m "$deploy_email" --nginx --agree-tos --non-interactive --domains "$backend_hostname","$frontend_hostname"
}

#######################################
# Bloqueia backend com PM2
#######################################
configurar_bloqueio() {
  print_banner
  echo "💻 Bloqueando backend da instância..."
  sleep 2

  sudo -u deploy pm2 stop ${empresa_bloquear}-backend
  sudo -u deploy pm2 save
}

#######################################
# Desbloqueia backend com PM2
#######################################
configurar_desbloqueio() {
  print_banner
  echo "💻 Desbloqueando backend da instância..."
  sleep 2

  sudo -u deploy pm2 start ${empresa_desbloquear}-backend
  sudo -u deploy pm2 save
}

#######################################
# Deleta instância completa
#######################################
deletar_tudo() {
  print_banner
  echo "💻 Deletando instância..."
  sleep 2

  sudo docker container rm redis-${empresa_delete} --force
  sudo rm -f /etc/nginx/sites-enabled/${empresa_delete}-frontend
  sudo rm -f /etc/nginx/sites-enabled/${empresa_delete}-backend
  sudo rm -f /etc/nginx/sites-available/${empresa_delete}-frontend
  sudo rm -f /etc/nginx/sites-available/${empresa_delete}-backend

  sudo -u postgres dropdb ${empresa_delete}
  sudo -u postgres dropuser ${empresa_delete}

  sudo -u deploy rm -rf /home/deploy/${empresa_delete}
  sudo -u deploy pm2 delete ${empresa_delete}-frontend ${empresa_delete}-backend || true
  sudo -u deploy pm2 save

  print_banner
  echo "✅ Instância ${empresa_delete} removida com sucesso."
  sleep 2
}