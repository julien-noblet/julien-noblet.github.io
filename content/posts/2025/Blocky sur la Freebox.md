---
categories:
- Présentations
- Docker
- Freebox
tags:
- freebox
- aarch64
- arm
- docker
- docker-compose

date: "2025-04-02T01:00:00+02:00"
draft: true
title: Blocky sur la Freebox
---
Depuis quelque temps, je remarque que de plus en plus de pubs sont très intrusives et s'invitent sur tous mes appareils !

J'ai donc décidé de mettre en place un DNS menteur qui va filtrer les sites que je ne veux pas.  
Ça ne supprimera pas tout, mais c'est un bon début !

J'ai une Freebox Delta à la maison. Elle permet de lancer des VM sans avoir besoin d'un Raspberry Pi ou d'une autre machine allumée en permanence.

## 1. Installation d'un disque ##
Vous devrez en installer un. Voici les étapes pour ajouter un disque à votre Freebox Delta :

**Achetez un disque dur compatible** : Assurez-vous de choisir un disque dur 2,5" SATA compatible avec la Freebox Delta. Je vous conseille de prendre un SSD, cela ne coûte pas très cher.

(Vous pourrez en profiter pour [ajouter de la RAM](https://plessy.me/augmenter-a-8go-la-ram-de-la-freebox-delta/))

Pour l'installation, c'est par ici : [Installer un (ou plusieurs) disque(s) dur(s) - Assistance Free](https://assistance.free.fr/articles/635)

Vous devrez ensuite le formater :  
Cela se passe dans votre interface [mafreebox](http://mafreebox.freebox.fr/), allez dans "Paramètres de la Freebox", puis, dans l'onglet "Mode Avancé", "Disque".

Choisissez votre disque et configurez-le comme ceci :  
![Formater le disque](/assets/images/2025/Blocky_sur_la_Freebox/Format.png)

## 2. Préparation de la VM ##
Toujours sur l'interface de la Freebox, allez dans le menu "VMs", et ajoutez une VM :  
![Ajout d'une VM](/assets/images/2025/Blocky_sur_la_Freebox/Creer_vm1.png)  
(vous pouvez lui donner un nom)

Ensuite, choisissez le système "Debian 12 (Bookworm)", changez l'utilisateur par défaut, vous pouvez aussi mettre votre clé publique SSH si vous en avez une... Pensez à mettre un mot de passe fort !

Lancez le téléchargement.

Une fois terminé, on va passer à 2 CPU pour notre VM  
(on a 2 CPU disponibles en tout, mais on ne va pas lancer plusieurs VM, on mutualisera sur notre VM les autres services).

On relance la VM.

Une fois démarrée, vous devriez avoir l'IP qui apparaît.

Connectez-vous via SSH.

Voici un petit script pour "accélérer la mise en place", au programme :  
- mise à jour de Debian  
- installation de Docker

```bash
#!/bin/bash

sudo apt update
sudo apt upgrade -y

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/{{ .chezmoi.osRelease.id }}/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

# EOF
```
Reconnectez-vous (pour avoir les droits sur Docker).

## 3. Le(s) docker-compose ##

Créez un dossier "*blocky*" et un sous-dossier "*docker-compose*" :
```bash
mkdir -p ~/blocky/docker-compose
```

Nous allons découper notre fichier *docker-compose* en plusieurs services.

### ~/blocky/docker-compose.yml ###
```yaml
name: blocky

include:
  - docker-compose/docker-compose.traefik.yml        # Reverse proxy
  - docker-compose/docker-compose.blocky.yml         # The Blocky-DNS service
  - docker-compose/docker-compose.lists-download.yml # Give blocking lists to blocky

networks:
  public:
    name: public_network
    driver: bridge
  
```

### ~/blocky/docker-compose/docker-compose.traefik.yml ###
```yaml
name: traefik

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      #- ./traefik:/dynamic:ro
    environment:
      TZ: Europe/Paris

    ports:
      # Port 80 is only used for redirecting to https; Some TLDs don't even support connecting to it (i.e. .dev).
      # Let's Encrypt will use a challenge on port 443 to verify the domain (TLS-ALPN-01);
      # See https://doc.traefik.io/traefik/https/acme/#tlschallenge for more information.
      - 80:80     # web
      - 443:443   # websecure
      - 8080:8080 # traefik internal
    networks:
      - blocky
      - public
      - traefik
    command:
      - --log.level=DEBUG
      - --log.format=json
      - --api.insecure=true
      - --entryPoints.web.address=:80
      - --providers.docker=true
      - --providers.docker.network=traefik
      # Do not expose containers unless explicitly told so
      - --providers.docker.exposedbydefault=false
      #- --providers.docker.allowEmptyServices=true
      - --entryPoints.websecure.address=:443
      - --ping=true
      - --metrics.addinternals
      - --metrics.prometheus.buckets=0.1,0.3,1.2,5.0
      - --accesslog=true
      - --accesslog.format=json
      - --providers.file.directory=/dynamic
      - --providers.file.watch=true

    restart: always
    healthcheck:
      # Run traefik healthcheck command
      # https://doc.traefik.io/traefik/operations/cli/#healthcheck
      test: [ "CMD", "traefik", "healthcheck", "--ping" ]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    dns: 1.1.1.1

networks:
  traefik:
    name: traefik
    internal: true

```

### ~/blocky/docker-compose/docker-compose.blocky.yml ###
```yaml
name: blocky

services:
  blocky:
    image: spx01/blocky:latest
    container_name: blocky
    depends_on:
      postgres:
        condition: service_healthy
        restart: true
      traefik:
        condition: service_healthy
    volumes:
      # load the configuration file config.yml from the volume blocky_config
      - blocky_config:/app/config.yml:ro
      # - ../queryLogs:/logs # we use postgresql
      - ../denylists:/app/denylists/
      - ../allowlists:/app/allowlists/
    environment:
      TZ: Europe/Paris
    ports:
      - '53:53/tcp'
      - '53:53/udp'
      - '4000:4000/tcp'
    networks:
      - blocky
      - public # Need to reach public DNSs.
      - traefik # Need to reach lists.
    restart: unless-stopped
    labels:
      prometheus.job: blocky
    cap_add:
      - NET_BIND_SERVICE
    cap_drop:
      - all
    dns: 1.1.1.1
    hostname: blocky
    security_opt:
      - no-new-privileges:true

  postgres:
    image: 'pgautoupgrade/pgautoupgrade:17-alpine'
    container_name: postgres
    volumes:
      - postgres:/var/lib/postgresql/data/
    environment:
      TZ: Europe/Paris
      POSTGRES_USER: blocky # The PostgreSQL user (useful to connect to the database)
      POSTGRES_PASSWORD: password # The PostgreSQL password (useful to connect to the database)
      POSTGRES_DB: blocky # The PostgreSQL default database (automatically created at first launch)
    # ports:
    #   - '5432:5432'
    networks:
      - blocky
    restart: unless-stopped
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "blocky" ]
      interval: 10s
      start_period: 30s
    # By default, a Postgres database is running on the 5432 port.
    # If we want to access the database from our computer (outside the container),
    # we must share the port with our computer's port.
    # The syntax is [port we want on our machine]:[port we want to retrieve in the container]
    # Note: You are free to change your computer's port,
    # but take into consideration that it will change the way
    # you are connecting to your database.
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.025'
          memory: 64M
    security_opt:
      - no-new-privileges:true

networks:
  blocky:
    # Give DNS!!!
    internal: true
    name: blocky_network

volumes:
  blocky_config:
    # ./blocky
    driver: local
    driver_opts:
      type: none
      device: ./blocky
      o: bind
  postgres:
```

### ~/blocky/docker-compose/docker-compose.lists-download.yml ###
```yaml
name: list_download

services:
  lists-download:
    image: shizunge/blocky-lists-updater:latest
    container_name: lists-download
    depends_on:
      traefik:
        condition: service_healthy
    volumes:
      - ../lists_updaters/sources:/sources/sources:ro
      - ../lists_updaters/watch:/web/watch:ro
      - bld-downloaded:/web/downloaded
      - ../blocky/index.html:/web/index.html:ro
    environment:
      # Possible values are DEBUG INFO WARN ERROR and NONE. Case sensitive.
      BLU_LOG_LEVEL: INFO
      # Add a location to the log messages.
      BLU_NODE_NAME: "{{.Node.Hostname}}"
      # Use an empty BLU_BLOCKY_URL to disable sending POST requests to the lists refresh API of blocky.
      BLU_BLOCKY_URL: http://blocky.local:4000
      # This should be under the BLU_WEB_FOLDER to be read by blocky.
      BLU_DESTINATION_FOLDER: /web/downloaded
      # Define the seconds to wait before the first download.
      BLU_INITIAL_DELAY_SECONDS: 60
      # Set BLU_INTERVAL_SECONDS to 0 to run the lists updater only once then exit.
      BLU_INTERVAL_SECONDS: 86400
      # Blocky won't read the sources files. It reads the downloaded files in the destination folder.
      BLU_SOURCES_FOLDER: /sources
      # Use an empty BLU_WATCH_FOLDER to disable watching lists of domains.
      # This should be under the BLU_WEB_FOLDER to be read by blocky.
      BLU_WATCH_FOLDER: /web/watch
      # Use an empty BLU_WEB_FOLDER to disable the static-web-server.
      BLU_WEB_FOLDER: /web
      # Port used by the static-web-server.
      BLU_WEB_PORT: 8080
    networks:
      - blocky
      # Need to reach internet to download lists.
      - public
      - traefik
    restart: unless-stopped

    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:8080/index.html" ]
      interval: 1m30s
      timeout: 30s
      retries: 5
      start_period: 10s
    labels:
      traefik.enable: true
      traefik.docker.network: traefik
      traefik.http.routers.rtr-lists-download.rule: PathPrefix(`/lists-download`)
      traefik.http.routers.rtr-lists-download.middlewares: stripprefix-lists-download@docker
      traefik.http.routers.rtr-lists-download.entrypoints: web
      traefik.http.middlewares.stripprefix-lists-download.stripprefix.prefixes: /lists-download
      traefik.http.routers.rtr-lists-download.service: svc-lists-download
      traefik.http.services.svc-lists-download.loadbalancer.server.port: 8080
      traefik.job: list_download

    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M
    # use 1.1.1.1 dns 
    dns: 1.1.1.1
volumes:
  bld-downloaded:
```

## 4. Configuration ##

On crée les différents dossiers:
```bash
mkdir -p ~/blocky/lists_updaters/watch ~/blocky/lists_updaters/sources ~/blocky/docker-compose/blocky
```

### ~/blocky/docker-compose/blocky/config.yml ###
```yaml
upstreams:
  groups:
    default:
      - 9.9.9.9
      - 149.112.112.112
      - https://dns.quad9.net/dns-query
      - tcp-tls:one.one.one.one:853
      - 1.1.1.1
      - 8.8.8.8
      - tcp-tls:fdns1.dismail.de:853
      - https://dns.digitale-gesellschaft.ch/dns-query
  strategy: parallel_best
  timeout: 5s
  init:
    strategy: fast
# bootstrapDns:
#   - upstream: https://9.9.9.9/dns-query
#   - upstream: tcp-tls:one.one.one.one:853
#     ips: 
#       - 1.1.1.1

# optional: Determines how blocky will create outgoing connections. This impacts both upstreams, and lists.
# accepted: dual, v4, v6
# default: dual
connectIPVersion: dual

caching:
  minTime: 1m
  maxTime: 0m
  maxItemsCount: 0
  prefetching: true
  prefetchExpires: 2h
  prefetchThreshold: 5
  prefetchMaxItemsCount: 0
  cacheTimeNegative: 30s

blocking:
  denylists:
    ads:
      #- https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
    groupe_one:
      - http://traefik/lists-download/downloaded/group_one.txt
    hagezi:
      - http://traefik/lists-download/downloaded/hagezi.txt
    my-lists:
      - http://traefik/lists-download/watch/blocked-list.txt
  allowlists:
    my-lists:
      - http://traefik/lists-download/watch/allowed-list.txt
  clientGroupsBlock:
    default:
      - ads
      - group_one
      - hagezi
      - my-lists
  blockType: zeroIp
  blockTTL: 1h
  loading:
    # Disable build-in refreshing, only listens to lists updater refreshing requests.
    refreshPeriod: 4h
    downloads:
      timeout: 5m
      attempts: 5
      cooldown: 5s
    concurrency: 4
    strategy: failOnError
    # Forgive the errors in the aggregate lists. The aggregate one also contains all errors from all of lists.
    maxErrorsPerSource: -1

customDNS:
  customTTL: 5m
  # optional: if true (default), return empty result for unmapped query types (for example TXT, MX or AAAA if only IPv4 address is defined).
  # if false, queries with unmapped types will be forwarded to the upstream resolver
  filterUnmappedTypes: true
  # optional: replace domain in the query with other domain before resolver lookup in the mapping
  rewrite:
    mafreebox: mafreebox.local
    dns: dns.local
  zone: |
    $ORIGIN local.
    dns     3600  A     192.168.1.X
    @       3600  CNAME dns
    mafreebox     A     192.168.1.254
    grafana       CNAME	dns
    blocky        CNAME	dns

clientLookup:
  # optional: this DNS resolver will be used to perform reverse DNS lookup (typically local router)
  upstream: 192.168.1.254
  # optional: some routers return multiple names for client (host name and user defined name). Define which single name should be used.
  # Example: take second name if present, if not take first name
  singleNameOrder:
    - 2
    - 1
  # optional: custom mapping of client name to IP addresses. Useful if reverse DNS does not work properly or just to have custom client names.
  clients:
    internal:

ports:
  dns: 53
  http: 4000
  # optional: Port(s) and bind ip address(es) for DoT (DNS-over-TLS) listener. Example: 853, 127.0.0.1:853
  #tls: 853
  # optional: Port(s) and optional bind ip address(es) to serve HTTPS used for prometheus metrics, pprof, REST API, DoH... If you wish to specify a specific IP, you can do so such as 192.168.0.1:443. Example: 443, :443, 127.0.0.1:443,[::1]:443
  #https: 443

prometheus:
  # enabled if true
  enable: true
  # url path, optional (default '/metrics')
  path: /metrics

# optional: write query information (question, answer, client, duration etc.) to daily csv file
queryLog:
  # optional one of: mysql, postgresql, timescale, csv, csv-client. If empty, log to console
  type: postgresql
  # directory (should be mounted as volume in docker) for csv, db connection string for mysql/postgresql
  target: postgres://blocky:password@postgres.blocky_network:5432/blocky
  #postgresql target: postgres://user:password@db_host_or_ip:5432/db_name
  # if > 0, deletes log files which are older than ... days
  logRetentionDays: 60
  # optional: Max attempts to create specific query log writer, default: 3
  creationAttempts: 60
  # optional: Time between the creation attempts, default: 2s
  creationCooldown: 5s
  # optional: Which fields should be logged. You can choose one or more from: clientIP, clientName, responseReason, responseAnswer, question, duration. If not defined, it logs all fields
  # fields:
  #   - clientIP
  #   - duration
  # optional: Interval to write data in bulk to the external database, default: 30s
  flushInterval: 30s

# optional: logging configuration
log:
  # optional: Log level (one from trace, debug, info, warn, error). Default: info
  level: info
  # optional: Log format (text or json). Default: text
  format: text
  # optional: log timestamps. Default: true
  timestamp: true
  # optional: obfuscate log output (replace all alphanumeric characters with *) for user sensitive data like request domains or responses to increase privacy. Default: false
  privacy: false

# optional: add EDE error codes to dns response
ede:
  # enabled if true, Default: false
  enable: false
```

Modifiez la zone à votre convenance :
```yaml
  zone: |
    $ORIGIN local.
    dns     3600  A     192.168.1.X
    @       3600  CNAME dns
    mafreebox     A     192.168.1.254
    grafana       CNAME	dns
    blocky        CNAME	dns
```

## 5. On lance ##

Placez-vous dans le dossier ~/blocky puis lancez le *docker-compose*.
```bash
cd ~/blocky
docker compose up -d
```
Docker va télécharger 
