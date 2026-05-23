.PHONY: init fmt lint test plan destroy

init:
	terraform init

fmt:
	terraform fmt -recursive

lint:
	tflint --recursive
	checkov -d .

test:
	cd test && go test -v -timeout 30m

plan:
	terraform plan

destroy:
	terraform destroy -auto-approve

bootstrap:
	cd bootstrap-state && terraform init && terraform apply -auto-approve
