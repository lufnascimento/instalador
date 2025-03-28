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

# Outras funções como bloquear, desbloquear, alterar domínio e deletar podem ser adicionadas seguindo esse padrão.

# Fim do script base melhorado