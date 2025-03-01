ENV_FILE := $(or $(ENV_FILE), .envrc)

include $(ENV_FILE)
export $(shell sed 's/=.*//' $(ENV_FILE))

format:
	terraform fmt

apply:
	chmod +x ./scripts/runner.sh
	./scripts/runner.sh "apply"

plan:
	chmod +x ./scripts/runner.sh
	./scripts/runner.sh "plan"

destroy:
	chmod +x ./scripts/runner.sh
	./scripts/runner.sh "destroy"

clean:
	rm -rf .terraform/ .terraform.lock.hcl