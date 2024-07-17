test:
	go install github.com/zoncoen/scenarigo/cmd/scenarigo@v0.17.1
	scenarigo plugin build -c ./scenarigo/scenarigo.yaml
	scenarigo run -c ./scenarigo/scenarigo.yaml

gen-api:
	oapi-codegen -old-config-style -generate "types" -package api ./app/openapi.yml > ./app/api/types.gen.go
	oapi-codegen -old-config-style -generate "chi-server" -package api ./app/openapi.yml > ./app/api/server.gen.go
	oapi-codegen -old-config-style -generate "spec" -package api ./app/openapi.yml > ./app/api/spec.gen.go

af-login:
	gcloud auth configure-docker asia-northeast1-docker.pkg.dev

init:
	cd infra && terraform init

plan:
	cd infra && terraform plan

apply:
	cd infra && terraform apply

destroy:
	cd infra && terraform destroy

fmt:
	cd infra && terraform fmt