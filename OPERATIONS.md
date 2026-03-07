# Common Operations for Demo Environments

This document outlines common operations you'll do in maintaining the
environments used for this demo.

> **NOTE**: Red Hat SSO access is required for creating assets from the Red Hat
> Demo Portal.

## Rotating OpenShift clusters and cloud credentials

Follow this guide when you need to change the OpenShift clusters used for
hosting ACM and/or the cloud providers used to host the managed clusters created
by it.

Once finished, re-visit the [README](./README.md) and re-deploy the environment
as described in the "Deploy!" section.

### Obtain the decryption secret for the demo config

#### For Red Hatters

Slack or e-mail any of the maintainers in in the
[`MAINTAINERS.md`](./MAINTAINERS) file to gain access to the Rover group for
this project.

Once you've been added, log into [Bitwarden](https://vault.bitwarden.com) with
your Red Hat SSO credentials. You'll see a new vault added to your account.

The decryption passphrase is contained in the `GPG Passphrase` field.

### Set up the ACM hubs

#### Manually

1. Create an OpenShift cluster in an AWS account.
2. Use sOps to update the kubeconfig and OpenShift console URL for this environment in `config.yaml`:

   ```sh
   export AWS_CONSOLE_URL=console-openshift-console.apps.$foo
   export KUBECONFIG_FILE=/path/to/kubeconfig/aws
   sops set config.yaml \
     '["environments"][1]["cluster"]["kubeconfig"]' \
     "$(yq -o=j -P '.' "$KUBECONFIG_FILE")"
   sops set config.yaml \
     '["environments"][1]["cluster"]["console_url"]' \
     "\"$AWS_CONSOLE_URL\""
   ```
3. Set the console URL for the AWS cluster:
   ```sh
   ```
3. Create an OpenShift cluster in an GCP project.
4. Use sOps to update the kubeconfig for this environment in `config.yaml`:

   ```sh
   export KUBECONFIG_FILE=/path/to/kubeconfig/gcp
   export GCP_CONSOLE_URL=console-openshift-console.apps.$foo
   sops set config.yaml \
     '["environments"][0]["cluster"]["kubeconfig"]' \
     "$(yq -o=j -P '.' "$KUBECONFIG_FILE")"
   sops set config.yaml \
     '["environments"][0]["cluster"]["console_url"]' \
     "$GCP_CONSOLE_URL"
   ```

#### For Red Hatters

1. Request the following demo catalogs if you haven't already:

   - AWS with OpenShift Open Environment
   - OpenShift 4 for Google Cloud Platform

   These will take 45 minutes or so to provision.

2. Use the SSH command provided in the Provisioning Notes for the
   AWS environment to obtain the kubeconfig for the AWS cluster:

   ```sh
   export AWS_BASTION=bastion.hostname.tld
   SSH_AUTH_SOCK= ssh "lab-user@$AWS_BASTION" 'cat ~/.kube/config' > /tmp/aws_kubeconfig
   ```

3. Do the same for the GCP environment:

   ```sh
   export GCP_BASTION=bastion.hostname.tld
   SSH_AUTH_SOCK= ssh "lab-user@$GCP_BASTION" 'cat ~/.kube/config' > /tmp/gcp_kubeconfig
   ```

4. Update `config.yaml` with the Kubeconfigs obtained:

    ```sh
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
      sops set config.yaml \
       '["environments"]['"$idx"']["cluster"]["kubeconfig"]' \
       "$(yq -o=j -P '.' "/tmp/${k}_kubeconfig")"
    done
    ```

5. Update `config.yaml` with the console URLs:

```sh
    export AWS_CONSOLE_URL=foo
    export GCP_CONSOLE_URL=bar
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
    ```


### Set up the managed cluster environments

These are the AWS and GCP accounts that will hold the managed clusters created
by the ACM hubs above.

#### AWS

##### Manually

1. Create an AWS account, if you don't already have one.
2. Create an IAM user with `AdministratorAccess` permissions.
3. Assign access keys for the IAM user, then download the CSV when prompted.

   > **NOTE**: This demo doesn't not support temporary credentials via AWS STS.
   > Guard these credentials carefully!

4. Update AWS credentials:

   ```sh
   export ACCESS_KEY_ID='your-access-key'
   export SECRET_ACCESS_KEY='your-secret-key'
   for key in \
     '["common"]["dns"]["settings"]["credentials"]["access_key_id"]' \
     '["common"]["datareplication"]["settings"]["object_store"]["access_key_id"]' \
     '["environments"][1]["cloud_config"]["credentials"]["aws_access_key_id"]' \
     '["common"]["dns"]["settings"]["credentials"]["secret_access_key"]' \
     '["common"]["datareplication"]["settings"]["object_store"]["secret_access_key"]' \
     '["environments"][1]["cloud_config"]["credentials"]["aws_secret_access_key"]'
     do
       case "$key" in
       *access_key_id*)
         sops set config.yaml "$key" "\"$ACCESS_KEY_ID\""
         ;;
       *secret_access_key*)
         sops set config.yaml "$key" "\"$SECRET_ACCESS_KEY\""
         ;;
       *)
        ;;
       esac
   done
   ```

5. Update the credentials file used for the OADP operator:

```sh
export ACCESS_KEY_ID='your-access-key'
export SECRET_ACCESS_KEY='your-secret-key'
file=$(cat <<-EOF
[default]
aws_access_key_id = $ACCESS_KEY_ID
aws_secret_access_key = $SECRET_ACCESS_KEY
EOF
)
sops set config.yaml \
  '["common"]["dataprotection"]["settings"]["aws"]["credentials_file"]' \
  "$(jq -n --arg v "$file" '$v')"
```

6. Create a public Route53 hosted zone. Register a domain for it if you haven't
   done so already.

7. Update the domain in `config.yaml`:

```sh
export DOMAIN='your-domain.com'
for key in '["common"]["dns"]["settings"]["domain_name"]' \
  '["environments"][1]["cloud_config"]["networking"]["domain"]'
  do sops set config.yaml "$key" "\"$DOMAIN\""
  done
```

##### For Red Hatters

Request the `AWS Blank Open Environment` catalog. This takes less than five
minutes to provision.

Once provisioned, take note of the `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`
and `Top level Route53 domain` properties in the "Provision Messages" section
**without the dot**.

Use those values to complete steps 4, 5 and 7 listed above.

#### GCP

##### Manually

1. Create a GCP account if you don't already have one.
2. Create a project in GCP to hold your managed cluster inside of.
3. Visit the IAM page, then click on "Service Accounts" then on "Create Service
   Account."
4. Give your service account a name, assign it the `Owner` role, then click
   "Done."
5. Click on your newly-created service account then click on "Keys."
6. Click on "Add Key". Leave "JSON" selected, then click "Create." This will
   download your service account's private key to your machine.
7. Update `config.yaml` with your new key:

```sh
export PROJECT_NAME=your-project-name
export SERVICE_ACCOUNT_KEY=~/Downloads/your-service-key.json
sops set config.yaml \
    '["environments"][0]["cloud_config"]["credentials"]["project"]' \
    "\"$PROJECT_NAME\""
sops set config.yaml \
    '["environments"][0]["cloud_config"]["credentials"]["service_account.json"]' \
    "$(jq -n --arg v "$(cat "$SERVICE_ACCOUNT_KEY")" '$v')"
```
8. Visit the "Cloud DNS" page, then create a new DNS zone. Register a domain if
   needed.
9. Update the domain in `config.yaml`:
```sh
export DOMAIN_GCP=your-domain
sops set config.yaml \
    '["environments"][0]["cloud_config"]["networking"]["domain"]' \
    "\"$DOMAIN_GCP\""
```

##### For Red Hatters

Request the `GCP Blank Open Environment` catalog. This takes less than five
minutes to provision.

Once provisioned, take note of the project ID and top level domain you've been
assigned. Use the URL provided to follow steps 3 through 7 and step 9 above.

> **NOTE**: **DO NOT** use the service account provided by RHDP, or you will run
> into provisioning issues when you attempt to create your managed cluster.
