.PHONY: up down logs psql apply seed

-include .env
export

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f postgres

psql:
	@docker exec -it rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

apply:
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/00_extensions.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/01_types.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/02_util.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/03_core_tenancy.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/04_external_metadata.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/05_documents_extraction.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/06_embeddings.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/07_collections.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/08_acl.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/09_chat_memory.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/10_ops_logs.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/11_functions.sql
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/12_rls_security.sql
seed:
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -f /sql/99_seed_demo.sql

reset:
	@echo "Resetting DB (DROPS EVERYTHING)..."
	@docker exec -i rag-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
	@"$(MAKE)" apply
	@"$(MAKE)" seed
