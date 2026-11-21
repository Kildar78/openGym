#!/usr/bin/env bash
# Sauvegarde ./data (profils, passkeys, séances, clé de session, médias) en archive datée.
#
#   ./deploy/vps/backup.sh                    archives dans ./backups, garde les 14 dernières
#   BACKUP_DIR=/srv/backups KEEP=30 ./deploy/vps/backup.sh
#   NO_MEDIA=1 ./deploy/vps/backup.sh         sans data/uploads (photos et vidéos), bien plus léger
#
# Tous les jours à 3 h (crontab -e) :
#   0 3 * * * /chemin/vers/openGym/deploy/vps/backup.sh >> /var/log/opengym-backup.log 2>&1
#
# L'archive contient data/secret et toutes les données des profils : stockez-la en lieu sûr.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"
KEEP="${KEEP:-14}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

[[ -d data ]] || { echo "Pas de dossier data/ dans $ROOT" >&2; exit 1; }

file="$BACKUP_DIR/opengym-$(date +%F-%H%M%S).tar.gz"
exclude=()
[[ "${NO_MEDIA:-}" == "1" ]] && exclude=(--exclude=data/uploads)

# Les écritures de l'API passent par fichier temporaire + rename : une copie à chaud est cohérente
# fichier par fichier, sans arrêter le service.
tar czf "$file" "${exclude[@]}" data/
chmod 600 "$file"
echo "$(date '+%F %T') sauvegarde : $file ($(du -h "$file" | cut -f1))"

# Rotation : on garde les $KEEP plus récentes.
ls -1t "$BACKUP_DIR"/opengym-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm -f
