.PHONY: lint test build publish deploy smoke promote rollback

lint:
	npm run lint

test: build
	npm run test
	npm run test:lhci

build:
	npm run build

publish:
	scripts/publish.sh $(SHA)

deploy:
	scripts/deploy.sh $(BUCKET) $(DISTRIBUTION_ID)

smoke:
	scripts/smoke-test.sh $(URL) $(SHA)

promote:
	scripts/promote.sh $(SHA) $(FROM) $(TO)

rollback:
	scripts/rollback.sh $(BUCKET) $(DISTRIBUTION_ID)
