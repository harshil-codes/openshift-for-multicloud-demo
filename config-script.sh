#!/usr/bin/env bash
export AWS_CONSOLE_URL=console-openshift-console.apps.cluster-mmptt.mmptt.sandbox3628.opentlc.com
export aws_CONSOLE_URL=console-openshift-console.apps.cluster-mmptt.mmptt.sandbox3628.opentlc.com
export GCP_CONSOLE_URL=console-openshift-console.apps.cluster-h4f8t.h4f8t.gcp.redhatworkshops.io
export gcp_CONSOLE_URL=console-openshift-console.apps.cluster-h4f8t.h4f8t.gcp.redhatworkshops.io
for k in aws gcp
    do
      case "$k" in
      aws)
        idx=1
        ;;
      gcp)
        idx=0
        ;;
      *)
        ;;
      esac
      var="${k^^}_CONSOLE_URL"
      sops set config.yaml \
       '["environments"]['"$idx"']["cluster"]["console_url"]' \
       "\"${!var}\""
    done
