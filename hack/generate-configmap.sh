#!/usr/bin/env bash

# This script generates configmap/s set by arguments
#
# To create a CI configmap use the "--ci" option
# To create an RHEL configmap use the "--rhel" option
# To create both configmaps use the "--all" option or pass no arguments

# Exit immediately if a command exits with a non-zero status
set -e

# Call the function teardown() on the exit of the script
trap teardown EXIT

teardown() {
	rm -rf "${TEMP_DIR}"
}

TEMP_DIR=$(mktemp -d -t keys-XXXXXXXX)
CONFIGMAP_FILENAME="0000_90_cluster-update-keys_configmap.yaml"

# Generates a public key specified by parameters in the TEMP_DIR directory
#
# $1 - Name of the key which will be generated
# $2 - Verifier public keys separated by internal field separator
#
generate_public_key() {
	truncate -s 0 "${TEMP_DIR}/key.gpg" # Empty the ${TEMP_DIR}key.gpg file
	for key in ${2}; do
		gpg --dearmor <"${key}" >>"${TEMP_DIR}/key.gpg"
	done
	gpg --enarmor <"${TEMP_DIR}/key.gpg" >"${TEMP_DIR}/${1}"
	sed -i 's/ARMORED FILE/PUBLIC KEY BLOCK/' "${TEMP_DIR}/${1}"
}

# Generates a configmap specified by parameters
#
# $1 - Name of a generated key in the TEMP_DIR directory
# $2 - Manifests folder
# $3 - Store files separated by internal field separator
#
generate_configmap() {
	stores=""
	for store in ${3}; do
		stores="--from-file=${store} ${stores}"
	done
	read -r -a stores <<<"$stores" # split string into an array

	oc create configmap release-verification -n openshift-config-managed \
		--from-file="${TEMP_DIR}/${1}" \
		"${stores[@]}" \
		--dry-run=client -o yaml |
		oc annotate -f - release.openshift.io/verification-config-map= \
			include.release.openshift.io/ibm-cloud-managed="true" \
			include.release.openshift.io/self-managed-high-availability="true" \
			include.release.openshift.io/single-node-developer="true" \
			-n openshift-config-managed --local --dry-run=client -o yaml \
			>>"${2}${CONFIGMAP_FILENAME}"
}

# Generates a CI configmap
#
# The CI system uses the OpenShift CI public key
# and verifies it against a bucket on GCS.
#
generate_ci_configmap() {
	configmap_data_key="verifier-public-key-ci"
	manifests_dir="manifests/"

	generate_public_key \
		${configmap_data_key} \
		"keys/verifier-public-key-openshift-ci 
		keys/verifier-public-key-openshift-ci-2"

	echo "# Release verification against OpenShift CI keys signed by the CI infrastructure" \
		>${manifests_dir}${CONFIGMAP_FILENAME}

	generate_configmap \
		${configmap_data_key} \
		${manifests_dir} \
		"stores/store-openshift-ci-release"
}

# Generates a RHEL configmap
#
# The Red Hat release contains the two primary Red Hat release keys from
# https://access.redhat.com/security/team/key as well as the beta 2 key. A future release
# will remove the beta 2 key from the trust relationship. The signature storage is a bucket
# on GCS and on mirror.openshift.com.
#
generate_rhel_configmap() {
	configmap_data_key="verifier-public-key-redhat"
	manifests_dir="manifests.rhel/"

	generate_public_key \
		${configmap_data_key} \
		"keys/verifier-public-key-redhat-release 
		keys/verifier-public-key-redhat-beta-2"

	echo "# Release verification against Official Red Hat keys" \
		>${manifests_dir}${CONFIGMAP_FILENAME}

	generate_configmap \
		${configmap_data_key} \
		${manifests_dir} \
		"stores/store-openshift-official-release 
		stores/store-openshift-official-release-mirror"
}

main() {
	if [ "$#" -eq "0" ]; then
		generate_ci_configmap
		generate_rhel_configmap
		exit
	fi

	while true; do
		case "$1" in
		--ci)
			generate_ci_configmap
			shift
			;;
		--rhel)
			generate_rhel_configmap
			shift
			;;
		--all)
			generate_ci_configmap
			generate_rhel_configmap
			shift
			;;
		*) break ;;
		esac
	done
}

main "$@"
