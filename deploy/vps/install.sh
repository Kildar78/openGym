#!/usr/bin/env bash
# Installe ou met à jour openGym sur un VPS Linux, avec les images précompilées.
#
#   Première installation :  ./deploy/vps/install.sh gym.mondomaine.com
#   Mise à jour :            ./deploy/vps/install.sh
#
# À lancer depuis n'importe où dans le dossier openGym cloné sur le VPS.
# Ne touche ni au DNS ni au reverse proxy : voir deploy/vps/README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mErreur :\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || fail "Docker n'est pas installé (https://docs.docker.com/engine/install/)."
docker compose version >/dev/null 2>&1 || fail "Le plugin Docker Compose manque (paquet docker-compose-plugin)."
docker info >/dev/null 2>&1 || fail "Impossible de joindre Docker. Lancez-le, ou ajoutez-vous au groupe docker."

DOMAIN="${1:-}"

if [[ ! -f .env ]]; then
  [[ -n "$DOMAIN" ]] || fail "Pas de .env : indiquez le domaine, par ex. $0 gym.mondomaine.com"
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || fail "Domaine invalide : '$DOMAIN' (sans https:// ni /)."
  say "Création de .env pour $DOMAIN"
  sed "s/gym\.example\.com/$DOMAIN/g" deploy/vps/env.vps.example > .env
  chmod 600 .env
elif [[ -n "$DOMAIN" ]]; then
  current="$(grep -E '^RP_ID=' .env | cut -d= -f2- || true)"
  if [[ "$current" != "$DOMAIN" ]]; then
    fail ".env existe déjà avec RP_ID=$current. Changer de domaine invalide les passkeys : modifiez .env à la main si c'est voulu."
  fi
fi

mkdir -p data coach-auth

if [[ -d .git ]]; then
  say "Mise à jour du dépôt (git pull)"
  git pull --ff-only || say "git pull impossible, on continue avec les fichiers actuels."
fi

say "Téléchargement des images"
docker compose pull

say "Démarrage"
docker compose up -d --remove-orphans

say "Vérification de l'API"
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/api/health >/dev/null 2>&1; then
    curl -fsS http://127.0.0.1:8080/api/health; echo
    origin="$(grep -E '^ORIGIN=' .env | cut -d= -f2-)"
    say "openGym tourne. Adresse publique : $origin"
    say "Créez votre profil admin tout de suite, avant de partager l'adresse."
    exit 0
  fi
  sleep 2
done

docker compose ps
fail "L'API ne répond pas sur 127.0.0.1:8080. Voir : docker compose logs --tail=50"
