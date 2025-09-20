
.PHONY: help build up down restart logs shell db-create db-migrate db-seed db-reset test clean

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build Docker images
	docker-compose build

up: ## Start all services
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Services are running!"
	@echo "Rails API: http://localhost:3000"

down: ## Stop all services
	docker-compose down

restart: ## Restart all services
	docker-compose restart

logs: ## View logs for all services
	docker-compose logs -f

logs-web: ## View logs for web service only
	docker-compose logs -f web

shell: ## Open Rails console in web container
	docker-compose exec web rails console

bash: ## Open bash shell in web container
	docker-compose exec web bash

db-create: ## Create database
	docker-compose exec web rails db:create

db-migrate: ## Run database migrations
	docker-compose exec web rails db:migrate

db-seed: ## Seed database with sample data
	docker-compose exec web rails db:seed

db-reset: ## Reset database (drop, create, migrate, seed)
	docker-compose exec web rails db:drop db:create db:migrate db:seed

db-console: ## Open PostgreSQL console
	docker-compose exec postgres psql -U postgres -d raneen_development

redis-cli: ## Open Redis CLI
	docker-compose exec redis redis-cli

test: ## Run tests
	docker-compose exec web rails test

routes: ## Show Rails routes
	docker-compose exec web rails routes

bundle: ## Install Ruby gems
	docker-compose exec web bundle install

status: ## Check status of all services
	docker-compose ps

clean: ## Clean up containers, volumes, and images
	docker-compose down -v
	docker system prune -f

setup: ## Initial setup (build, create db, migrate, seed)
	make build
	make up
	@echo "Waiting for database to be ready..."
	@sleep 10
	make db-create
	make db-migrate
	make db-seed
	@echo ""
	@echo "✅ Setup complete!"
	@echo "Rails API is running at: http://localhost:3000"
	@echo ""
	@echo "Test the API:"
	@echo "  curl http://localhost:3000/health"
	@echo "  curl http://localhost:3000/api/discovery/programs"
	@echo ""
	@echo "⚠️  Remember to configure your AWS credentials in .env file!"

# Quick commands
dev: up logs-web ## Start development environment and show logs

stop: down ## Alias for down