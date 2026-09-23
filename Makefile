COMPOSE = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/aasylbye/data

all: up

build:
		$(COMPOSE) build

up: $(DATA_DIR)
		$(COMPOSE) up -d --build

down:
		$(COMPOSE) down

clean: down
	docker system prune -af

fclean: clean
	$(COMPOSE) down -v
	sudo rm -rf $(DATA_DIR)

re: fclean up

$(DATA_DIR):
		mkdir -p $(DATA_DIR)/db_data
		mkdir -p $(DATA_DIR)/wordpress_files

.PHONY: all build up down clean fclean re