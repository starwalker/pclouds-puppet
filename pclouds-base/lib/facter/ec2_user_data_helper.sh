#!/bin/bash

# A helper bash script to turn a list of arguments into separate
# name and values.  Arguments are separated by spaces and " can be
# used to allow values to include spaces.

function explode_args {
        while [[ "$1" != "" ]]; do
                if [[ "$1" =~ .*= ]]; then
                        VARNAME=${1%%=*}
                        VARVAL=${1#*=}
                else
                        VARNAME=$1
                        VARVAL="true"
                fi
                echo "$VARNAME:==:$VARVAL"
                shift
        done
}

UDARGS=`curl -s http://169.254.169.254/latest/user-data | sed -e 's/^args[ ]*:[ ]*//' | awk 'BEGIN{printit=1}($1 ~ /^---/){printit=0;getline} (printit == 1){print}'`
#UDARGS='access_key=AKIAIAKF4TCXGGWZUSIA secret_key=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 Name=centami64 domain=ec2.practicalclouds.com platform=live bootbucket=pclouds-live-bootbucket profile=amitools amibucket=pceu1 manifest=CentOS6.2-x86_64-practicalclouds-puppet.manifest.xml amicredentials=ami-user-credentials amialiases=amialiases-centos6.2 debug'
if [[ "$UDARGS" != "" ]]; then
        eval explode_args $UDARGS
else
	exit 1
fi
