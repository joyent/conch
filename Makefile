.PHONY: test run morbo build format deps install-deps generate-dbic watch-perl\
	watch doc migrate-db watch-test

run: build morbo ## Default. Build and run under morbo

morbo: ## Run under morbo, listening on :5001
	@carton exec -- morbo -v bin/conch -l http://\*:5001

build: local ## Install deps (TODO: and build docs)

local: cpanfile.snapshot ## Install deps
# '--deployment' installs the same dep versions that are in the lockfile
	@carton install --deployment
	@touch local

test: local ## Run tests
	@carton exec prove -lpr t/

# Exclude Schema files generated by dbicdump
format: ## Run perltidy
	@find lib \
		-path lib/Conch/Legacy/Schema -prune \
		-o -name "*.pm" -not -name "Schema*" -type f -exec perltidy {} +
	@find lib -name "*.bak" -delete
	@find t -name "*.t"  -type f -exec perltidy {} +
	@find t -name "*.bak" -delete

doc: public/doc/index.html ## Build docs

public/doc/index.html: \
	docs/conch-api/openapi-spec.yaml \
	docs/conch-api/yarn.lock docs/conch-api/index.js
	@cd docs/conch-api && yarn install && yarn run render
	@mkdir -p public/doc
	@cp docs/conch-api/index.html public/doc/index.html

watch-test:
	@find lib t | entr -r -c make test

generate-dbic: dbic 

.PHONY: dbic
dbic: ## Regenerate DBIC schemas
	@carton exec dbicdump schema.conf
	@make db-schema

migrate-db: ## Apply database migrations
	@sql/run_migrations.sh
	@make db-schema

.PHONY: db-schema
db-schema: ## create a dump of current db schema
	pg_dump -U conch -s conch > sql/schema.sql

validation_docs: docs/validation/BaseValidation.md docs/validation/BaseValidation.md

# pod2github is installed with Pod::Github
docs/validation/BaseValidation.md: lib/Conch/Validation.pm
	@pod2github lib/Conch/Validation.pm > docs/validation/BaseValidation.md

docs/validation/TestingValidations.md: lib/Test/Conch/Validation.pm
	@pod2github lib/Test/Conch/Validation.pm > docs/validation/TestingValidations.md

.PHONY: help
help: ## Display this help message
	@echo "GNU make(1) targets:"
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

