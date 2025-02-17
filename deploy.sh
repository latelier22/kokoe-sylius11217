#!/bin/bash

# Définir les variables
USER="debian"           # Utilisateur SSH sur le VPS
HOST="vps.latelier22.fr" # Adresse IP de votre VPS
REMOTE_DIR="/home/debian/kokoe" # Répertoire sur le serveur où l'application sera déployée
LOCAL_DIR="./"           # Répertoire local contenant votre code Sylius

# Effectuer la synchronisation avec rsync
echo "Déploiement de l'application Sylius sur le VPS..."

# Exécuter rsync et rediriger la sortie dans le fichier rsync.log
rsync -avz --delete --exclude='vendor/' --exclude='node_modules/'  --exclude='build/' --quiet --log-file='rsync.log' $LOCAL_DIR/ $USER@$HOST:$REMOTE_DIR/

# Vérifier si l'exécution a réussi
if [ $? -eq 0 ]; then
  echo "La synchronisation a réussi, maintenant l'installation des dépendances..."
else
  echo "Erreur lors de la synchronisation. Veuillez vérifier rsync.log pour plus de détails."
  exit 1
fi

# Se connecter en SSH et installer les dépendances
ssh $USER@$HOST << ENDSSH
  echo "Mise à jour du serveur et installation des dépendances..."

  # Se rendre dans le répertoire de l'application
  cd $REMOTE_DIR

  # Installer les dépendances PHP avec Composer
  composer install --optimize-autoloader

  # Installer les dépendances Node.js avec pnpm
  sudo pnpm i

  # Construire les assets frontend avec pnpm
  sudo pnpm run build

  # Configuration des permissions des fichiers
  sudo chown -R www-data:www-data $REMOTE_DIR
  sudo chmod -R 775 $REMOTE_DIR
  sudo chmod -R 777 public/media/cache
  sudo chown -R www-data:www-data public/media/cache
  sudo chown -R www-data:www-data public/media/image
  sudo chmod -R 777 public/media/image

  # Vider le cache
  php bin/console cache:clear 

  # Assurez-vous que les assets sont générés
  php bin/console asset:install --symlink 

  # Si nécessaire, mettez à jour la base de données
  php bin/console doctrine:migrations:migrate --no-interaction

  # Redémarrer le serveur web (Nginx ou Apache)
  sudo systemctl restart nginx

  echo "Déploiement terminé avec succès !"
ENDSSH

echo "Déploiement terminé sur le serveur."
