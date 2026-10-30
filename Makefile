# Lumen shortcuts. `make help` lists them.
.PHONY: help setup up down logs ps console psql build size dev test lint

help: ## Show this help
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

setup: ## Create .env with a random DB password and your master key (first run only)
	@test -f .env && echo ".env already exists, leaving it alone." || { \
	  printf "POSTGRES_PASSWORD=%s\nRAILS_MASTER_KEY=%s\nLUMEN_PORT=3000\n" \
	    "$$(openssl rand -hex 24)" "$$(cat config/master.key)" > .env && chmod 600 .env && echo "Created .env"; }

up: ## Build and start Lumen in Docker → http://localhost:3000
	docker compose up -d --build
	@echo "Lumen is starting at http://localhost:$$(grep -s '^LUMEN_PORT=' .env | cut -d= -f2 || echo 3000)"

down: ## Stop containers (data volumes are kept)
	docker compose down

logs: ## Follow app logs
	docker compose logs -f app

ps: ## Show container status and memory use
	docker compose ps
	docker stats --no-stream $$(docker compose ps -q)

console: ## Rails console inside the running app container
	docker compose exec app bin/rails console

psql: ## psql shell on the production database
	docker compose exec db psql -U lumen lumen_production

build: ## Build the app image only
	docker compose build app

size: ## Show the app image size (target ≤ 250 MB, PRD DKR-2)
	@docker image inspect lumen:latest --format '{{.Size}}' | awk '{printf "lumen:latest = %.0f MB\n", $$1/1000/1000}'

dev: ## Run locally without Docker (Rails :3000 + Vite :3036)
	bin/dev

test: ## Run backend + frontend tests and typecheck
	bin/rails test
	npm test
	npm run typecheck

lint: ## RuboCop + Brakeman
	bin/rubocop
	bin/brakeman -q --no-pager
