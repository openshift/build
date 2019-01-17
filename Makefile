#This makefile is used by ci-operator

CGO_ENABLED=0
GOOS=linux
CORE_IMAGES=./cmd/controller/ ./cmd/nop ./cmd/webhook
CORE_IMAGES_WITH_GIT=./cmd/creds-init ./cmd/git-init/
TEST_IMAGES=./test/panic/

install:
	go install $(CORE_IMAGES) $(CORE_IMAGES_WITH_GIT)
.PHONY: install

test-install:
	go install $(TEST_IMAGES)
.PHONY: test-install

test-e2e:
	sh openshift/e2e-tests-openshift.sh
.PHONY: test-e2e

# Generate Dockerfiles used by ci-operator. The files need to be committed manually.
generate-dockerfiles:
	./openshift/ci-operator/generate-dockerfiles.sh openshift/ci-operator/Dockerfile.in openshift/ci-operator/knative-images $(CORE_IMAGES)
	./openshift/ci-operator/generate-dockerfiles.sh openshift/ci-operator/Dockerfile-git.in openshift/ci-operator/knative-images $(CORE_IMAGES_WITH_GIT)
	./openshift/ci-operator/generate-dockerfiles.sh openshift/ci-operator/Dockerfile.in openshift/ci-operator/knative-test-images $(TEST_IMAGES)
.PHONY: generate-dockerfiles
