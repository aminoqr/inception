# Developer Documentation

This document explains how to set up this project from scratch, build and run
it, manage it day to day, and understand where its data lives.

## Prerequisites

- A virtual machine running Debian (this project is built and tested on
  Debian 13 under VirtualBox).
- Docker Engine and the Docker Compose plugin, installed inside that VM:
  ```
  sudo apt update
  sudo apt install -y docker.io docker-compose
  ```
- Your user added to the `docker` group, so Docker commands don't need `sudo`:
  ```
  sudo usermod -aG docker $USER
  ```
  Log out and back in (or reboot the VM) for this to take effect.

## Setting up the environment from scratch

Clone the repository:
```
git clone git@github.com:aminoqr/inception.git
cd inception
```

Two files are required but not included in the repository, because they hold
credentials. Git is configured to ignore both, so they have to be created by
hand on every machine this project is set up on.

`srcs/.env` holds non-secret configuration:
```
DOMAIN_NAME=aasylbye.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_TITLE=Inception
WP_ADMIN_USER=bossman
WP_ADMIN_EMAIL=aasylbye@example.com
WP_USER=editor
WP_USER_EMAIL=editor@example.com
```

`secrets/` holds the passwords, one value per file:

- `secrets/db_password.txt`, a single line, the WordPress database user's
  password.
- `secrets/db_root_password.txt`, a single line, MariaDB's root password.
- `secrets/credentials.txt`, two lines:
  ```
  WP_ADMIN_PASSWORD=yourpassword
  WP_USER_PASSWORD=yourpassword
  ```

The domain also needs to resolve somewhere. Add this to `/etc/hosts` on
whatever machine will browse to the site:
```
127.0.0.1 aasylbye.42.fr
```

## Building and launching

Everything runs through the `Makefile` at the repository root, which wraps
`docker compose -f srcs/docker-compose.yml`.

| Command | What it does |
| --- | --- |
| `make` / `make up` | Create the data directories if missing, build all three images, start the containers |
| `make build` | Build the images without starting anything |
| `make down` | Stop and remove the containers, leaving the data volumes alone |
| `make clean` | `down`, then remove unused Docker images and build cache |
| `make fclean` | `clean`, then remove the named volumes and delete the data directories entirely |
| `make re` | `fclean` followed by `up`, a full wipe and rebuild |

The first `make` takes a few minutes: it downloads the base Debian image,
installs packages inside each container, and downloads WordPress itself. Later
runs are faster, since Docker reuses layers that have not changed.

## Managing containers and volumes

List the containers and their status:
```
docker compose -f srcs/docker-compose.yml ps
```

Open a shell, or run a single command, inside a container:
```
docker exec -it wordpress bash
docker exec wordpress wp user list --allow-root
```

Read a container's logs:
```
docker compose -f srcs/docker-compose.yml logs mariadb
```

List the named volumes and inspect where they are stored on disk:
```
docker volume ls
docker volume inspect srcs_db_data
```

Simulate a crash to confirm the restart policy works, by signaling the
container's main process directly rather than using `docker kill` (a
user-initiated stop, which does not trigger `restart: always`):
```
docker exec wordpress kill -QUIT 1
```

## Where the data lives, and how it persists

Two named volumes hold everything the project needs to keep:

- `db_data`, mounted at `/var/lib/mysql` inside the MariaDB container, holding
  the database files.
- `wordpress_files`, mounted at `/var/www/html` inside both the WordPress and
  NGINX containers, holding WordPress's PHP files, uploads, and themes.

Both are declared in `srcs/docker-compose.yml` with `driver_opts` that point
them at a fixed location on the host:
```
/home/aasylbye/data/db_data
/home/aasylbye/data/wordpress_files
```

This means the data survives `make down` and container restarts, since
removing a container does not touch its volumes. It also means the data can be
inspected directly from the VM's own filesystem at that path, without going
through Docker at all.

Only `make fclean` (or a manual `docker compose down -v` followed by deleting
that directory) destroys this data. Every other command in the table above
leaves it untouched.
