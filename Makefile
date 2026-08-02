.PHONY: lint test build docker-build tag-version deploy smoke promote rollback mark-stable

lint:
	npm run lint

test: build
	npm run test
	npm run test:lhci

build:
	npm run build

docker-build: build
	docker build -t $(REPOSITORY_URL):$(VERSION) .

tag-version:
	scripts/tag-version.sh $(VERSION) $(SHA)

deploy:
	scripts/deploy-ecs.sh $(SERVICE_ARN) $(CLUSTER) $(SERVICE_NAME) $(REPOSITORY_URL) $(VERSION)

smoke:
	scripts/smoke-test.sh $(URL) $(SHA)

mark-stable:
	scripts/mark-stable.sh $(ENV) $(VERSION)

promote:
	scripts/promote-image.sh $(SOURCE_REPOSITORY_URL) $(REPOSITORY_URL) $(VERSION)

rollback:
	scripts/rollback-ecs.sh $(SERVICE_ARN) $(CLUSTER) $(SERVICE_NAME) $(REPOSITORY_URL) $(ENV)
