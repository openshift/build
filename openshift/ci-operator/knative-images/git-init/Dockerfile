# Do not edit! This file was generated via Makefile
FROM registry.svc.ci.openshift.org/openshift/origin-v4.0:base

RUN yum install -y git openssh-client

ADD git-init /usr/bin/git-init
ENTRYPOINT ["/usr/bin/git-init"]
