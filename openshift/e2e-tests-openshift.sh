#!/bin/sh

source $(dirname $0)/../vendor/github.com/knative/test-infra/scripts/e2e-tests.sh
source $(dirname $0)/release/resolve.sh

set -x

readonly API_SERVER=$(oc config view --minify | grep server | awk -F'//' '{print $2}' | awk -F':' '{print $1}')
readonly OPENSHIFT_REGISTRY="${OPENSHIFT_REGISTRY:-"registry.svc.ci.openshift.org"}"
readonly INTERNAL_REGISTRY="${INTERNAL_REGISTRY:-"image-registry.openshift-image-registry.svc:5000"}"
readonly INSECURE="${INSECURE:-"false"}"
readonly TEST_NAMESPACE=build-tests
readonly TEST_YAML_NAMESPACE=build-tests-yaml
readonly BUILD_NAMESPACE=knative-build
readonly TARGET_IMAGE_PREFIX="$INTERNAL_REGISTRY/$BUILD_NAMESPACE/knative-build-"
readonly IGNORES="git-volume|gcs-archive|docker-basic"

env

function install_build(){
  header "Installing Knative Build"
  
  # Create knative-build namespace, needed for imagestreams
  oc create namespace $BUILD_NAMESPACE
  
  # Grant the necessary privileges to the service accounts Knative will use:
  oc adm policy add-scc-to-user anyuid -z build-controller -n $BUILD_NAMESPACE
  oc adm policy add-cluster-role-to-user cluster-admin -z build-controller -n $BUILD_NAMESPACE

  create_build

  wait_until_pods_running $BUILD_NAMESPACE || return 1

  header "Knative Build Installed successfully"
}

function create_build(){
  resolve_resources config/ build-resolved.yaml $TARGET_IMAGE_PREFIX

  tag_images build-resolved.yaml

  oc apply -f build-resolved.yaml
}

function tag_images(){
  local resolved_file_name=$1

  oc policy add-role-to-group system:image-puller system:authenticated --namespace=$BUILD_NAMESPACE

  echo ">> Creating imagestream tags for images referenced in yaml files"
  IMAGE_NAMES=$(cat $resolved_file_name | grep -i "image:" | grep "$INTERNAL_REGISTRY" | awk '{print $2}' | awk -F '/' '{print $3}')
  for name in $IMAGE_NAMES; do
    tag_built_image ${name} ${name}
  done
}

function tag_built_image() {
  local remote_name=$1
  local local_name=$2
  oc tag --insecure=${INSECURE} -n ${BUILD_NAMESPACE} ${OPENSHIFT_REGISTRY}/${OPENSHIFT_BUILD_NAMESPACE}/stable:${remote_name} ${local_name}:latest
}

function create_test_namespace(){
  oc new-project $TEST_YAML_NAMESPACE
}

function run_go_e2e_tests(){
  header "Running Go e2e tests"
  go_test_e2e ./test/e2e/... -timeout=20m --kubeconfig $KUBECONFIG || return 1
}

function run_yaml_e2e_tests() {
  header "Running YAML e2e tests"
  oc project $TEST_YAML_NAMESPACE
  resolve_resources test/ tests-resolved.yaml $TARGET_IMAGE_PREFIX

  tag_images tests-resolved.yaml

  oc apply -f tests-resolved.yaml

  # The rest of this function copied from test/e2e-common.sh#run_yaml_tests()
  # The only change is "kubectl get builds" -> "oc get builds.build.knative.dev"
  oc get project
  # Wait for tests to finish.
  echo ">> Waiting for tests to finish"
  local tests_finished=0
    for i in {1..60}; do
      sleep 10
      local finished="$(oc get builds.build.knative.dev --output=jsonpath='{.items[*].status.conditions[*].status}')"
      if [[ ! "$finished" == *"Unknown"* ]]; then
        tests_finished=1
        break
      fi
    done
  if (( ! tests_finished )); then
    echo "ERROR: tests timed out"
    return 1
  fi

  # Check that tests passed.
  local failed=0
  echo ">> Checking test results"
  for expected_status in succeeded failed; do
    results="$(oc get builds.build.knative.dev -l expect=${expected_status} \
	--output=jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[*].type}{.status.conditions[*].status}{" "}{end}')"
    case $expected_status in
      succeeded)
      want=succeededtrue
      ;;
          failed)
      want=succeededfalse
      ;;
          *)
      echo "ERROR: Invalid expected status '${expected_status}'"
      failed=1
      ;;
    esac
    for result in ${results}; do
      if [[ ! "${result,,}" == *"=${want}" ]]; then
        echo "ERROR: test ${result} but should be ${want}"
        failed=1
      fi
    done
  done
  (( failed )) && return 1
  echo ">> All YAML tests passed"
  return 0
}

function delete_build_openshift() {
  echo ">> Bringing down Build"
  oc delete --ignore-not-found=true -f build-resolved.yaml
  # Make sure that are no builds or build templates in the knative-build namespace.
  oc delete --ignore-not-found=true builds.build.knative.dev --all -n $BUILD_NAMESPACE
  oc delete --ignore-not-found=true buildtemplates.build.knative.dev --all -n $BUILD_NAMESPACE
}

function delete_test_resources_openshift() {
  echo ">> Removing test resources (test/)"
  oc delete --ignore-not-found=true -f tests-resolved.yaml
}

 function delete_test_namespace(){
   echo ">> Deleting test namespace $TEST_NAMESPACE"
   oc delete project $TEST_YAML_NAMESPACE
 }

function teardown() {
  delete_test_resources_openshift
  delete_test_namespace
  delete_build_openshift
}

failed=0

install_build || failed=1

(( !failed )) && create_test_namespace || failed=1

(( !failed )) && run_go_e2e_tests || failed=1

(( !failed )) && run_yaml_e2e_tests || failed=1

(( failed )) && dump_cluster_state

teardown

(( failed )) && exit 1

success
