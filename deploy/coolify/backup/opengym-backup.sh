#!/bin/sh
# Sauvegarde du volume de données openGym. Tourne DANS le conteneur opengym-backup (Alpine),
# lancé par crond chaque nuit. Le volume est monté en lecture seule sur /data,
# les archives vont dans /backups (= ~/backups/opengym sur le VPS).
#
# Variables (fixées par install-backup.sh) :
#   KEEP          nombre d'archives gardées (14 par défaut)
#   BACKUP_OWNER  uid:gid propriétaire des archives sur l'hôte
#   NO_MEDIA=1    exclut data/uploads (photos et vidéos), archives bien plus légères
set -eu

KEEP="${KEEP:-14}"
stamp="$(date +%F-%H%M%S)"
tmp="/backups/.opengym-$stamp.tar.gz.part"
file="/backups/opengym-$stamp.tar.gz"

# « secret » est écrit au premier démarrage de l'API (db.json n'apparaît qu'au premier profil).
[ -f /data/secret ] || { echo "$(date '+%F %T') ERREUR : /data/secret absent, volume mal monté ?"; exit 1; }

set -- czf "$tmp" -C / data
[ "${NO_MEDIA:-}" = "1" ] && set -- czf "$tmp" --exclude=data/uploads -C / data

# Les écritures de l'API passent par fichier temporaire + rename : la copie à chaud est
# cohérente fichier par fichier, sans arrêter le service.
tar "$@"
# Archive écrite en .part puis renommée : jamais d'archive tronquée qui ait l'air complète.
mv "$tmp" "$file"
chmod 600 "$file"
[ -n "${BACKUP_OWNER:-}" ] && chown "$BACKUP_OWNER" "$file"

echo "$(date '+%F %T') sauvegarde OK : $(basename "$file") ($(du -h "$file" | cut -f1))"

# Rotation : on garde les $KEEP plus récentes.
ls -1t /backups/opengym-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm -f
