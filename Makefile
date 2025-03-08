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