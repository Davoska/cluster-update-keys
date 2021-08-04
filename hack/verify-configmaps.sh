#!/usr/bin/env bash

bash hack/generate-configmap.sh && git diff --exit-code
