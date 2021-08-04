all: ci rhel
.PHONY: all

# The CI system uses the OpenShift CI public key and verifies it against a bucket on GCS.
ci:
	bash hack/generate-configmap.sh --ci
.PHONY: ci

# The Red Hat release contains the two primary Red Hat release keys from
# https://access.redhat.com/security/team/key as well as the beta 2 key. A future release
# will remove the beta 2 key from the trust relationship. The signature storage is a bucket
# on GCS and on mirror.openshift.com.
rhel:
	bash hack/generate-configmap.sh --rhel
.PHONY: rhel
