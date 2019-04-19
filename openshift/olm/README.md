
This is the `CatalogSource` for the
[knative-build-operator](https://github.com/openshift-knative/knative-build-operator).

WARNING: The `knative-build` operator requires a CRD provided by the
`knative-serving` `CatalogSource`, so install it first.

To install this `CatalogSource`:

    OLM=$(kubectl get pods --all-namespaces | grep olm-operator | head -1 | awk '{print $1}')
    kubectl apply -n $OLM -f https://raw.githubusercontent.com/openshift/knative-build/release-v0.5.0/openshift/olm/knative-build.catalogsource.yaml

To subscribe to it (which will trigger the installation of
knative-build), either use the console, or apply the following:

	---
	apiVersion: v1
	kind: Namespace
	metadata:
	  name: knative-build
	---
	apiVersion: operators.coreos.com/v1
	kind: OperatorGroup
	metadata:
	  name: knative-build
	  namespace: knative-build
	---
	apiVersion: operators.coreos.com/v1alpha1
	kind: Subscription
	metadata:
	  name: knative-build-operator-sub
	  generateName: knative-build-operator-
	  namespace: knative-build
	spec:
	  source: knative-build-operator
	  sourceNamespace: olm
	  name: knative-build-operator
	  startingCSV: knative-build-operator.v0.5.0
	  channel: alpha
