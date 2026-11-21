#!/usr/bin/env bash
# Installe (ou réinstalle) la sauvegarde nocturne du volume openGym déployé par Coolify.
# À lancer sur le VPS, par un utilisateur du groupe docker, sans sudo :
#
#   ./install-backup.sh                       volume détecté automatiquement
#   VOLUME=xxx_opengym-data ./install-backup.sh
#   KEEP=30 SCHEDULE="30 2 * * *" ./install-backup.sh
#
# Crée un conteneur « opengym-backup » (Alpine + crond, redémarre avec Docker) qui monte le
# volume en lecture seule et écrit dans ~/backups/opengym. Heure : celle de Paris.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${DEST:-$HOME/backups/opengym}"
KEEP="${KEEP:-14}"
SCHEDULE="${SCHEDULE:-0 3 * * *}"
IMAGE="${IMAGE:-alpine:3.22}"
# Heure de Paris sans le paquet tzdata (chaîne POSIX : CET/CEST, changements fin mars / fin octobre).
TZ_POSIX='CET-1CEST,M3.5.0,M10.5.0/3'

VOLUME="${VOLUME:-$(docker volume ls --format '{{.Name}}' | grep -E '_opengym-data$' | head -1)}"
[[ -n "$VOLUME" ]] || { echo "Aucun volume *_opengym-data trouvé. Indiquez VOLUME=..." >&2; exit 1; }

mkdir -p "$DEST"
chmod 700 "$DEST"
install -m 755 "$HERE/opengym-backup.sh" "$DEST/.opengym-backup.sh"

docker rm -f opengym-backup >/dev/null 2>&1 || true
docker run -d --name opengym-backup --restart unless-stopped \
  --log-opt max-size=1m --log-opt max-file=3 \
  -e TZ="$TZ_POSIX" -e KEEP="$KEEP" -e BACKUP_OWNER="$(id -u):$(id -g)" -e NO_MEDIA="${NO_MEDIA:-}" \
  -v "$VOLUME":/data:ro \
  -v "$DEST":/backups \
  -v "$DEST/.opengym-backup.sh":/usr/local/bin/opengym-backup:ro \
  "$IMAGE" \
  sh -c "echo '$SCHEDULE /bin/sh /usr/local/bin/opengym-backup > /proc/1/fd/1 2>&1' | crontab - && exec crond -f -l 8" \
  >/dev/null

echo "Conteneur opengym-backup lancé : volume $VOLUME → $DEST, planning « $SCHEDULE » (heure de Paris), $KEEP archives gardées."
echo "Sauvegarde immédiate de test :"
docker exec opengym-backup /bin/sh /usr/local/bin/opengym-backup
