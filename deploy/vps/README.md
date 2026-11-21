# Déployer openGym sur un VPS, sur un sous-domaine

Ce guide installe openGym sur `https://gym.mondomaine.com`, avec les images précompilées. Il n'y a rien à compiler et Node n'est pas nécessaire sur le VPS. Dans tout le guide, remplacez `gym.mondomaine.com` par votre sous-domaine.

```
Internet ──HTTPS──► reverse proxy du VPS (Caddy ou nginx, :443)
                         │
                         ▼  127.0.0.1:8080 (invisible depuis Internet)
                    conteneur web (nginx) ──/api──► conteneur api (Node) ──► ./data
```

## Ce qu'il faut

- Un VPS Linux avec **Docker** et le plugin **Compose** (`docker compose version` doit répondre).
- Les ports **80 et 443** ouverts sur le VPS, pour le certificat Let's Encrypt et le HTTPS.
- Environ 2 Go de disque pour les images, plus la place des données.

## 1. DNS

Chez votre registrar ou votre fournisseur DNS, créez un enregistrement **A** `gym` vers l'IPv4 du VPS, et un **AAAA** si le VPS a une IPv6. Vérifiez ensuite que le nom pointe bien sur le VPS :

```bash
dig +short gym.mondomaine.com
```

> **Important :** les passkeys sont liées pour toujours à ce nom exact. Choisissez le sous-domaine définitif avant que quelqu'un crée un profil.

## 2. Récupérer openGym et le lancer

```bash
cd /opt
sudo git clone https://github.com/DuarteSantos8/openGym opengym
sudo chown -R $USER: opengym
cd opengym
```

Copiez ensuite le dossier `deploy/vps/` de ce poste dans `/opt/opengym/deploy/vps/` sur le VPS (avec `scp -r` ou `rsync`), puis :

```bash
chmod +x deploy/vps/*.sh
./deploy/vps/install.sh gym.mondomaine.com
```

Le script :

- crée `.env` à partir de [env.vps.example](env.vps.example), avec votre domaine, `WEB_PORT=127.0.0.1:8080`, le premier profil en admin et le français par défaut ;
- télécharge les images ;
- démarre les conteneurs ;
- vérifie `/api/health`.

## 3. HTTPS : choisir un reverse proxy

**Option 1 : Caddy.** C'est le plus simple, le certificat est automatique.

```bash
sudo apt install -y caddy        # Debian/Ubuntu, voir caddyserver.com pour les autres
```

Collez le bloc de [Caddyfile](Caddyfile) dans `/etc/caddy/Caddyfile`, avec votre domaine, puis :

```bash
sudo systemctl reload caddy
```

**Option 2 : nginx déjà présent sur le VPS.** Suivez les commandes en tête de [nginx-opengym.conf](nginx-opengym.conf) : copie, lien, `nginx -t`, puis `certbot --nginx`.

**Option 3 : Traefik ou Nginx Proxy Manager déjà en place.** Routez `gym.mondomaine.com` vers `127.0.0.1:8080`. Autorisez des requêtes d'au moins 112 Mo et un délai de lecture de 10 minutes. Pour Traefik, cela se règle avec `readTimeout` sur l'entryPoint.

**Cloudflare.** Avec le nuage orange ou un tunnel, décommentez `CF_CONNECTING_IP` dans `.env`. Sachez que l'offre gratuite limite les envois à 100 Mo.

## 4. Premier lancement

1. Ouvrez `https://gym.mondomaine.com` et cliquez sur **Créer un nouveau profil**. Ce premier profil devient **admin**.
2. Pour une instance privée (vous et quelques proches), éditez `.env`, décommentez `INVITE_ONLY=1` et `ALLOW_GUEST=0`, puis lancez `docker compose up -d`. Les codes d'invitation se créent dans Réglages → Compte → Tableau de bord admin.

> Après une modification de `.env`, lancez toujours `docker compose up -d`. Un simple `restart` ne relit pas le fichier.

## 5. Sauvegardes

Tout tient dans `./data` : profils, passkeys, séances, clé de session et médias. Le script [backup.sh](backup.sh) crée une archive datée dans `./backups` et garde les 14 dernières. Pour le lancer chaque nuit :

```bash
crontab -e
# puis ajoutez la ligne :
0 3 * * * /opt/opengym/deploy/vps/backup.sh >> /opt/opengym/backups/backup.log 2>&1
```

Copiez aussi ces archives **hors du VPS**, par exemple avec rsync, rclone ou la sauvegarde de votre hébergeur. Elles contiennent `data/secret` et toutes les données des utilisateurs.

Pour restaurer :

```bash
docker compose down
tar xzf backups/opengym-AAAA-MM-JJ-HHMMSS.tar.gz
docker compose up -d
```

## 6. Mises à jour

```bash
cd /opt/opengym && ./deploy/vps/install.sh
```

Sans argument, le script fait `git pull`, télécharge les nouvelles images et redémarre. `./data` n'est pas touché. Le rythme des versions est d'environ une toutes les une à deux semaines ; elles sont annoncées dans les releases GitHub.

## Dépannage

| Symptôme | Cause probable |
|---|---|
| La page s'affiche mais la passkey échoue | `RP_ID` ou `ORIGIN` ne correspond pas exactement à l'adresse dans le navigateur (`https://`, pas de slash final, pas de chemin) |
| « Le serveur a refusé le fichier, trop grand » | Limite de taille ou délai trop court dans le reverse proxy (voir étape 3) |
| 502 Bad Gateway | Les conteneurs ne tournent pas : `docker compose ps`, `docker compose logs --tail=50` |
| Le certificat ne s'obtient pas | DNS pas encore propagé, ou port 80 fermé dans le pare-feu |

Le guide complet en anglais est dans [docs/SELF_HOSTING.md](../../docs/SELF_HOSTING.md).
