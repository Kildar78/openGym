# Sauvegarde nocturne d'openGym (Coolify)

Coolify ne sauvegarde que les bases de données, pas les volumes d'une application. Ce dossier
ajoute un petit conteneur `opengym-backup` (Alpine + crond) qui archive le volume
`<uuid>_opengym-data` chaque nuit à **3 h, heure de Paris**, et garde les **14** dernières archives
dans `~/backups/opengym` sur le VPS. Il redémarre avec Docker et ne demande pas de sudo, seulement
d'être dans le groupe `docker`.

## Installer ou réinstaller

```bash
mkdir -p ~/opengym-backup     # puis y copier opengym-backup.sh et install-backup.sh
~/opengym-backup/install-backup.sh
```

Le script trouve le volume tout seul, relance le conteneur et fait une sauvegarde de test.
Réglages possibles : `KEEP=30`, `SCHEDULE="30 2 * * *"`, `NO_MEDIA=1` (sans les photos et vidéos),
`VOLUME=...`, `DEST=...`.

## Vérifier

```bash
ls -la ~/backups/opengym              # les archives
docker logs opengym-backup            # une ligne « sauvegarde OK » par nuit
docker exec opengym-backup /bin/sh /usr/local/bin/opengym-backup   # une sauvegarde maintenant
```

## Restaurer

Dans Coolify, **Stop** la ressource openGym, puis sur le VPS :

```bash
V=$(docker volume ls --format '{{.Name}}' | grep -E '_opengym-data$')
docker run --rm -v "$V":/data -v ~/backups/opengym:/backups alpine:3.22 \
  sh -c 'rm -rf /data/* && tar xzf /backups/opengym-AAAA-MM-JJ-HHMMSS.tar.gz -C /'
```

Puis **Start** dans Coolify.

## À savoir

- Les archives contiennent `secret` (clé des sessions) et toutes les données des profils : droits
  600, dossier 700.
- Elles sont sur le **même disque** que l'application. Pour survivre à la perte du VPS, copiez
  aussi `~/backups/opengym` ailleurs (rsync, rclone, votre PC).
