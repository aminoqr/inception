# User Documentation

This document explains how to use the Inception project: what it provides, how
to start and stop it, how to reach the site, where credentials live, and how to
confirm everything is running.

## What this stack provides

The project runs a WordPress website behind an encrypted connection. Three
services work together:

- NGINX accepts HTTPS connections on port 443. It is the only service reachable
  from outside the virtual machine.
- WordPress, running through php-fpm, generates the actual pages: posts, the
  admin panel, everything a visitor sees.
- MariaDB stores the site's data: posts, users, settings. It is only reachable
  from the other two containers, never directly from outside.

## Starting and stopping the project

Run these commands from the root of the repository, where the `Makefile` is.

Start everything:
```
make
```

Stop everything (containers are removed, the database and site files are kept):
```
make down
```

Rebuild after a Dockerfile or config file changes:
```
make re
```

`make re` deletes the stored data along with everything else. Only use it when
starting over on purpose.

## Accessing the site

Open a browser and go to:
```
https://aasylbye.42.fr
```

The certificate is self-signed, so the browser shows a warning the first time.
That is expected. Accept it to continue.

The administration panel is at:
```
https://aasylbye.42.fr/wp-admin
```

Log in with the administrator account described below.

## Locating and managing credentials

Login details are not published anywhere, including in this file. They are set
by whoever created the project's `secrets/` folder and `srcs/.env` file, both
kept out of version control.

- The administrator username is set in `srcs/.env`, under `WP_ADMIN_USER`.
- The administrator password is set in `secrets/credentials.txt`, under
  `WP_ADMIN_PASSWORD`.
- A second WordPress account exists with the `author` role, for a regular
  contributor rather than an administrator. Its username and password live in
  the same two files, under `WP_USER` and `WP_USER_PASSWORD`.

Whoever administers this project should keep a copy of these values somewhere
safe outside the repository. Deleting `secrets/` or `srcs/.env` removes the
only record of them.

## Checking that services are running correctly

List the containers and their status:
```
docker compose -f srcs/docker-compose.yml ps
```

Each of the three services (`mariadb`, `wordpress`, `nginx`) should show `Up`.
MariaDB also shows `(healthy)` once it has confirmed the database is answering
queries. WordPress waits for that before starting, so if MariaDB stays
unhealthy, WordPress will not come up either.

Check what a specific service has printed since it started:
```
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx
```

If the site does not load in a browser, this is the first place to look.

The final check is the site itself: load `https://aasylbye.42.fr` and confirm
the page appears, then log in to `/wp-admin` and confirm the dashboard loads.
