*This project has been created as part of the 42 curriculum by aasylbye.*

# Inception

## Description

Inception is a system administration exercise. The goal is to build a small web
infrastructure from scratch using Docker, with each service isolated in its own
container, and to run the whole thing inside a virtual machine.

The stack is a WordPress site served over HTTPS:

```
browser --443--> [nginx] --9000--> [wordpress + php-fpm] --3306--> [mariadb]
                                          |                            |
                                   wordpress_files                  db_data
```

Three containers, one Docker network, two named volumes. NGINX terminates TLS and
is the only way in. WordPress runs as php-fpm with no web server of its own.
MariaDB holds the site database and is not reachable from outside the network.

Every image is built from a Dockerfile in this repository, starting from a pinned
Debian base. No pre-built service images are pulled.

## Instructions

### Requirements

- A virtual machine running Debian (this project is built and tested on Debian 13
  under VirtualBox)
- Docker Engine and the Docker Compose plugin installed inside that VM
- Your user added to the `docker` group

### Setup

Clone the repository, then create the two files that are deliberately kept out of
git because they hold credentials.

`srcs/.env`:

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

`secrets/db_password.txt` and `secrets/db_root_password.txt` each hold a single
password with no newline. `secrets/credentials.txt` holds two lines:

```
WP_ADMIN_PASSWORD=yourpassword
WP_USER_PASSWORD=yourpassword
```

Point the domain at the machine running the browser by adding a line to
`/etc/hosts`:

```
127.0.0.1 aasylbye.42.fr
```

### Running it

```
make
```

This creates the data directories under `/home/aasylbye/data`, builds the three
images, and starts the containers in the background. The first run takes a few
minutes because it installs packages and downloads WordPress.

Then open `https://aasylbye.42.fr`. The certificate is self-signed, so the browser
warns about it once.

Other targets:

| Command | What it does |
| --- | --- |
| `make` / `make up` | Build images and start containers |
| `make build` | Build images without starting anything |
| `make down` | Stop and remove the containers |
| `make clean` | `down`, then remove unused images and build cache |
| `make fclean` | `clean`, then delete the data directories (destroys the database and site files) |
| `make re` | `fclean` then `up` |

## Project description

### What Docker is doing here

A Docker image is a filesystem plus some metadata, built by running the
instructions in a Dockerfile. A container is one running instance of an image.
Compose reads `srcs/docker-compose.yml`, builds each image, creates the network
and volumes, and starts the containers with the right environment, secrets and
mounts.

### Sources included

```
Makefile                    entry point, wraps docker compose
secrets/                    passwords, never committed
srcs/
  docker-compose.yml        services, network, volumes, secrets
  .env                      non-secret configuration, never committed
  requirements/
    mariadb/
      Dockerfile
      conf/my.cnf           bind-address override
      tools/entrypoint.sh   first-run database setup, then mariadbd
    wordpress/
      Dockerfile
      conf/www.conf         php-fpm pool, listens on TCP 9000
      tools/entrypoint.sh   first-run WordPress install, then php-fpm
    nginx/
      Dockerfile            also generates the self-signed certificate
      conf/nginx.conf       TLS settings and fastcgi_pass
```

### Design choices

The base image is `debian:bookworm-slim`, pinned. The subject asks for the
penultimate stable release of Alpine or Debian, and I picked Debian because the
VM already runs Debian, so the package names and tooling are the same in both
places. The `latest` tag is forbidden, and it would be a bad idea anyway: an image
that changes underneath you is an image you cannot debug.

Each container ends by running its real daemon in the foreground. MariaDB and
WordPress use small entrypoint scripts that finish with `exec mariadbd` and
`exec php-fpm -F`. `exec` replaces the shell process instead of spawning a child,
so the daemon becomes PID 1 and receives signals from Docker directly. That is
what makes `docker stop` shut down cleanly and the restart policy fire on a crash.
NGINX needs no script at all, because it already has a flag for this:
`nginx -g "daemon off;"`.

Setup runs once, guarded by a check. Both entrypoint scripts test for something
that only exists after a successful install: `/var/lib/mysql/mysql` for MariaDB,
`wp-config.php` for WordPress. Both paths sit on named volumes, so that state
survives restarts, and the setup block runs on the first start and is skipped
afterwards. Without the guard, every restart would re-run `CREATE USER` and error
out.

That guard exposed a problem worth recording here. Installing `mariadb-server`
with apt initializes `/var/lib/mysql` during the image build, and Docker copies
existing image content into an empty named volume the first time it mounts one.
The guard was finding a database that Debian's package had created rather than one
this project had set up, and skipping the setup silently. The Dockerfile now
clears `/var/lib/mysql` after installing, so the volume starts empty.

Waiting for the database is Compose's job here, not the shell's. MariaDB has a
`healthcheck` that authenticates with the root password read from its secret file,
and WordPress declares `depends_on: mariadb: condition: service_healthy`. Compose
will not start WordPress until MariaDB answers. That replaces the retry loop that
would otherwise live in the WordPress entrypoint.

### Virtual Machines vs Docker

A virtual machine emulates hardware and boots a complete operating system with its
own kernel. A container is a group of processes on the host kernel, isolated with
namespaces and cgroups, with its own filesystem view.

That difference shows up in what each one costs. Each of these three services is a
package install and a config file, and a container starts them without a boot
sequence at all. Running them as three VMs would mean three kernels, three boot
sequences, and gigabytes of disk for what amounts to three daemons.

The cost is isolation. Containers share the host kernel, so a kernel-level
compromise is not contained the way it would be in a VM. This project uses both:
the containers give per-service isolation, and the VM gives a boundary between the
whole stack and the machine it runs on.

### Secrets vs Environment Variables

Environment variables are visible. `docker inspect` prints them,
`docker compose config` prints them, and every child process a container spawns
inherits them. That is fine for a database name and a username, which is what
`srcs/.env` holds.

Docker secrets are files mounted into the container at `/run/secrets/<name>`.
Reading one is explicit: the MariaDB entrypoint does
`DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)`, and the healthcheck reads
the same file each time it runs. The value never appears in the container's
environment, in `docker inspect`, or in the compose file.

Neither mechanism is encrypted at rest here, and both sets of files stay out of
git through `.gitignore`. The difference is exposure surface, not encryption.

### Docker Network vs Host Network

`docker-compose.yml` defines a bridge network named `inception`. Containers on it
get their own network namespace and their own IP, and Docker resolves service
names for them: `nginx.conf` says `fastcgi_pass wordpress:9000`, and WordPress
connects to a host called `mariadb`. Neither needs to know an IP address, which
matters because those addresses change whenever containers are recreated.

With host networking, containers share the VM's network stack. Service name
resolution would not exist, so everything would talk over `localhost`, and port
3306 and port 9000 would be listening on the VM itself. The subject forbids
`network: host` for this reason, and it also forbids `--link`, the deprecated
predecessor to user-defined networks. With the bridge network, only nginx
publishes anything: `443:443`. MariaDB and WordPress are reachable from inside the
network and nowhere else.

### Docker Volumes vs Bind Mounts

A bind mount attaches a host directory straight into a container, written in a
service's `volumes:` list as `/host/path:/container/path`. Docker does not manage
it and does not know anything about it; it is whatever is at that path.

A named volume is an object Docker tracks. It shows up in `docker volume ls`, is
created and destroyed with the stack, and, when it is mounted empty for the first
time, is seeded with whatever the image already has at that path.

This project uses two named volumes, `db_data` and `wordpress_files`. The subject
requires named volumes and also requires the data to live under
`/home/login/data`, so both are declared with `driver_opts`:

```yaml
  db_data:
    driver: local
    driver_opts:
      type: none
      device: /home/aasylbye/data/db_data
      o: bind
```

The `o: bind` option means the volume is backed by that exact host directory, so
the storage mechanism ends up resembling a bind mount. The volume itself is still
a named volume that Docker manages and that the services refer to by name, which is
how both requirements are met at once.

`wordpress_files` is mounted into two containers, WordPress and NGINX, at
`/var/www/html`. WordPress writes the site files there, and NGINX reads them to
serve static assets and to work out which PHP file to hand to php-fpm.

## Resources

Documentation:

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [nginx documentation](https://nginx.org/en/docs/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/documentation/)
- [WP-CLI](https://wp-cli.org/)
- `man` pages and the `/etc/` config files inside the Debian containers, which is
  where the php-fpm socket default and the MariaDB config layout were found

### Use of AI

I used Claude Code throughout this project.

It read the subject PDF and turned it into a milestone plan (`MILESTONES.md`),
which broke the work into pieces I could finish and test one at a time instead of
writing everything and debugging it all at once.

Before writing each file I had it explain what the pieces did: image layers and
why `apt-get update` and the cache cleanup belong in the same `RUN`, the difference
between `ENTRYPOINT` exec form and shell form and why it decides what PID 1 is,
what `fastcgi_pass` does, how php-fpm pools work.

It produced the contents of the Dockerfiles, configs, entrypoint scripts,
`docker-compose.yml` and `Makefile`. I typed all of them out by hand rather than
pasting, so I had to read every line. Partway through I asked it to replan the
project for simplicity, after the first version of the MariaDB entrypoint turned
out to be more complicated than I could explain.

Debugging was the largest part. I pasted container logs and it worked out what they
meant. The bugs it helped identify: `/run/mysqld` missing, because containers never
run the boot process that normally creates it; the pre-seeded `/var/lib/mysql`
defeating the first-run guard; `service mariadb start` depending on a
`debian-sys-maint` account that a manual `mariadb-install-db` never creates; the
`php-fpm` binary installed under a version-suffixed name; php-fpm listening on a
Unix socket that another container cannot reach; and a Compose healthcheck that
could not authenticate once the root password was set.

It also caught mistakes by reading rather than running: YAML list syntax errors in
`docker-compose.yml`, backticks versus quotes in the SQL heredoc, and an entrypoint
script that had been pasted into itself twice.

I can explain every file in this repository.
