## OpenShift Multicloud Demo

This README will walk you through demonstrating how OpenShift, ACM, Portworx and CockroachDB
simplifies multi-cloud disaster recovery by failing over a simple
application between two clusters in separate cloud providers.

Contact anyone in the [MAINTAINERS](./MAINTAINERS) file if you have questions
or need help!

- [Setting up](#setting-up)
- [Deploy!](#deploy-the-environment)
- [Run the demo](#run-the-demo)
- [Teardown](#teardown)
- [Demo Concepts](#demo-concepts)

## Setting up

### Prerequisites

- GnuPG (`brew install gnupg` or `dnf -y install gnupg`)
- sOPs (Visit [this
  page](https://github.com/getsops/sops?tab=readme-ov-file#1download) for
  installation instructions
- Existing OpenShift clusters in AWS and GCP (tested with 4.19)

### Instructions

#### SSH and GPG Setup

1. Fork this repository so that you can commit and push your changes.
   [Click
   here](https://github.com/carlosonunez/openshift-for-multicloud-demo/fork) to do that.

2. Create a GPG keypair, if you don't have one already. This will be used to
   encrypt Kubernetes secrets that will be used by your ACM hubs and their
   managed Kubernetes clusters, like cloud credentials and OpenShift install
   configs.

    ```sh
    gpg --quick-gen-key --batch --yes --passphrase '' your@email.address
    ```

3. Confirm that your key has been created by running the command below:

    ```sh
    gpg --list-keys your@email.address
    ```

    which should produce output similar to the below:

    ```sh
    gpg: checking the trustdb
    gpg: marginals needed: 3  completes needed: 1  trust model: pgp
    gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
    gpg: next trustdb check due at 2028-10-13
    pub   ed25519 2025-10-14 [SC] [expires: 2028-10-13]
          ABCDEF01234567890ABCDEF01234567890ABCDEF
    uid           [ultimate] your@email.address
    sub   cv25519 2025-10-14 [E]
    ```

4. Create an SSH key. This will be used by Flux and ArgoCD to clone this
   repository and deploy the ACM hubs and managed OpenShift clusters (by Flux)
   as well as our demo application and its dependencies (by Argo).

    ```sh
    ssh-keygen -t rsa -f /tmp/id_rsa -q -N ''
    ```

#### Creating a config

The configuration for our ACM hubs, managed clusters, operators and apps lives
in `config.yaml` at the root of our repository. This file is encrypted with sOps
so that we can store our configuration securely alongside our clusters and
preserve changes made to it into our history.

Follow the steps below to create a new one.

1. Retrieve the kubeconfigs for the clusters in AWS and GCP that you'd like the
   ACM hubs in this demo environment to be hosted inside of.

2. Create a new config file from the example:

    ```sh
    rm config.yaml && cp config.example.yaml config.yaml
    ```

   **WARNING**: `config.yaml` is **NOT** ready to be modified securely yet.
   Follow the steps below to encrypt it first.

3. Run the command below to obtain the fingerprint for the GPG key that you created:

    ```sh
    gpg --list-keys --with-colons your@email.address | \
        grep fpr | \
        head -1 | \
        rev | \
        cut -f2 -d ':' | \
        rev
    ```

4. Open `.sops.yaml` in an editor and update the `pgp` keys in `.sops.yaml` with
   the fingerprint you obtained above.

5. Encrypt the `config.yaml` file that you created:

   ```sh
   sops encrypt --output config.yaml config.yaml
   ```

   This will not produce any output if it succeeds.

6. Run this command to verify that `config.yaml` was encrypted:

   ```sh
   sops filestatus config.yaml
   ```

   This should produce the output below:

   ```json
   {"encrypted":"true"}
   ```

   Congratulations! Your config is now encrypted and can be modified securely
   with `sops`.

7. We're now ready to update our config. Run `sops config.yaml` to open a
   decrypted copy of `config.yaml` in an editor, then make the following
   changes:

   - Set the `kubeconfig` key in the `gcp` environment to the kubeconfig of the
     OpenShift cluster in GCP that you'd like ACM to be hosted in.

   - Set the `kubeconfig` key in the `aws` environment to the kubeconfig of your
     OpenShift cluster in AWS that you'd like ACM to be hosted in.

   - The OpenShift cluster in AWS is the "primary" ACM hub that managed
     clusters and GitOps will be hosted out of. To change this, set
     `acm_config.role` to `primary` underneath the `gcp` environment and
     `acm_config.role` underneath the `aws` environment to `backup`.

   - Replace anything that says `change me` with actual values. See the comments
     above the keys for guidance on what to replace them with.

## 🛫 Deploy the Environment

Run the deploy script

```sh
# Add --help to see what else you can do with this script.
deploy.sh --regenerate-secrets
```

This will do the following:

- Replace Kubernetes secrets encrypted with the upstream project's GPG key with
  Secrets created with your GPG key,

- Create an AWS S3 bucket to store backups of your ACM hub that will be used for
  the "ACM failover" part of this demo ([Ansible
  task](./tasks/create_backup_s3_bucket.yaml))

- Install Flux into the "primary" ACM hub ([Ansible
  task](./tasks/create_flux_subscription.yaml)),

- Configure Flux to synchronize this repository with your ACM hub using the SSH
  key you created earlier ([Ansible
  task](./tasks/create_flux_subscription.yaml)),

- Wait 45 minutes for ACM to create managed OpenShift clusters in AWS and GCP
  ([Ansible task](./tasks/wait_until_managed_clusters_ready.yaml))

- Add ingress rules to the AWS Security Group for the managed cluster in AWS and
  the GCP Firewall for the managed cluster to allow Portworx and CockroachDB
  pods to talk to each other across regions ([Ansible
  task](./tasks/modify_managed_cluster_security_groups.yaml)), and

- Create a [cluster
  pair](https://docs.portworx.com/portworx-enterprise/3.3/operations/disaster-recovery/async-dr/generate-apply-clusterpair)
  between the managed clusters in AWS and GCP to enable near-zero RPO asynchronous replicated
  storage ([Ansible task](./tasks/create_px_async_cluster_pair.yaml)).

### Watching progress

The environment will take about an hour to provision.

ACM, ACM backups and the managed clusters in AWS and GCP are managed by Flux.
You can watch its progress by running the commands below:

```sh
# `dnf -y install watch` or `brew install watch` if you get a
# "no such file or directory" error
watch -n 0.5 kubectl --kubeconfig /path/to/kubeconfig/for/primary/acm/hub \
    get kustomization,clusterdeployment,applications.argoproj.io -A
```

You'll see something like the output shown below when this is done:

```sh
Every 0.5s: kubectl get kustomization,clusterdeployment,applications.argoproj.io -A  bastion.6jxv2.internal: Wed Nov 19 14:28:55 2025

NAMESPACE     NAME                                                                             AGE     READY   STATUS
flux-system   kustomization.kustomize.toolkit.fluxcd.io/argocd-server-options                  6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cloud-installconfig-secrets-aws        6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cloud-installconfig-secrets-gcp        6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-acm-clusterset                 6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-acm-hub                        6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-acm-mce                        6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-config                         6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-operators-acm                  6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-operators-gitops               6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-operators-multiclusterengine   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-secrets-aws                    6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/cluster-secrets-gcp                    6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/dataprotection-app                     6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/dataprotection-secrets                 6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/gitops-cluster-aws                     6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/gitops-cluster-gcp                     6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/gitops-mcsb                            6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cloud-credential-secrets-aws   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cloud-credential-secrets-gcp   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-aws                    6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-aws-apps               6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-aws-gitops-placement   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-aws-operators          6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-aws-resources          6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-gcp                    6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-gcp-apps               6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-gcp-gitops-placement   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-gcp-operators          6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/managed-cluster-gcp-resources          6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/mch-backup-schedule                    6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/submariner-addon-aws                   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/submariner-addon-gcp                   6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4
flux-system   kustomization.kustomize.toolkit.fluxcd.io/submariner-broker                      6d13h   True    Applied revision: refs
/heads/main@sha1:da287d3a66dd058bcc9b816bf1d90095c18b5cd4

NAMESPACE             NAME                                                      INFRAID                     PLATFORM   REGION      VE
RSION   CLUSTERTYPE   PROVISIONSTATUS   POWERSTATE                   AGE
managed-cluster-aws   clusterdeployment.hive.openshift.io/managed-cluster-aws   managed-cluster-aws-kkk6q   aws        us-east-2   4.
18.26                 Provisioned       WaitingForClusterOperators   6d13h
managed-cluster-gcp   clusterdeployment.hive.openshift.io/managed-cluster-gcp   managed-cluster-gcp-5qbxp   gcp        us-east1    4.
18.26                 Provisioned       Running                      6d13h

NAMESPACE          NAME                                                    SYNC STATUS   HEALTH STATUS
openshift-gitops   application.argoproj.io/managed-cluster-aws-apps        Synced        Healthy
openshift-gitops   application.argoproj.io/managed-cluster-aws-operators   Synced        Healthy
openshift-gitops   application.argoproj.io/managed-cluster-aws-resources   Synced        Healthy
openshift-gitops   application.argoproj.io/managed-cluster-gcp-apps        Synced        Healthy
openshift-gitops   application.argoproj.io/managed-cluster-gcp-operators   Synced        Healthy
openshift-gitops   application.argoproj.io/managed-cluster-gcp-resources   Synced        Healthy

```

Afterwards, ArgoCD will provision the demo application and its CockroachDB database and
Portworx storage into both managed clusters.

To see the status of these resources from the console UI:

1. Click the tile menu on the upper-right corner, then click on "Cluster Argo
   CD".

![](./static/images/argocd-tile-menu.png)

2. You should be able to see synced resources after logging in with OpenShift.

![](./static/images/argocd-synced-applications.png)

You're ready to go when all of the applications are in **Synced** and
**Healthy** states.

> **NOTE**: You can also see the status of these resources from the CLI by
> running the command below.
>
> ```sh
> # change "aws" to "gcp" if you want to see how the managed cluster in GCP
> # is progressing
> cloud=aws
> watch -n 0.5 kubectl --kubeconfig <(kubectl --kubeconfig /path/to/kubeconfig/for/primary/acm/hub \
>     get secret -n "managed-cluster-$cloud" -l hive.openshift.io/secret-type=kubeconfig \
>     -o jsonpath='{.items[0].data.raw-kubeconfig}' | base64 -d) \
>     get storagecluster,deployment -A -n example-todo-app
> ```


### 📝 Perform the demo

1. Get the routes for the OpenShift consoles in the primary and secondary ACM
   hubs:

```sh
console_primary=$(kubectl --kubeconfig /path/to/kubeconfig/for/primary/acm/hub get route \
    -n openshift-console console jsonpath='{.spec.host}')
console_backup=$(kubectl --kubeconfig /path/to/kubeconfig/for/backup/acm/hub get route \
    -n openshift-console console jsonpath='{.spec.host}')
echo "Primary: $console_primary"
echo "Backup: $console_backup"
```

2. In the primary ACM hub, verify that there are backups available in the S3
   bucket created during deployment:

   ```sh
   kubectl --kubeconfig .../hub get backups -A
   ```

   You should see a list similar to the below:

   ```sh
   NAMESPACE                        NAME                                            AGE
   open-cluster-management-backup   acm-credentials-schedule-20251119004415         13h
   open-cluster-management-backup   acm-managed-clusters-schedule-20251119004415    13h
   open-cluster-management-backup   acm-resources-generic-schedule-20251119004415   13h
   open-cluster-management-backup   acm-resources-schedule-20251119004415           13h
   open-cluster-management-backup   acm-validation-policy-schedule-20251119004415   13h
   ```

3. Log into both OpenShift consoles. Change `local-cluster` to all clusters.

   In the "primary" ACM hub, verify that `managed-cluster-aws` and
   `managed-cluster-gcp` managed clusters are **Healthy**.

   ![](./static/images/primary_acm_hub_all_clusters.png)

   In the "backup" ACM hub, there should be no clusters in this screen.

   ![](./static/images/backup_acm_hub_all_clusters.png)


### 🛬 Tear everything down!

_Work in progress._

### Customizations

#### Adding workers

You might need to add additional workers to your existing clusters depending on
the app being demonstrated. To do that:

1. In the `infra/cluster/aws/kustomization.yaml` file, add `- machinesets.yaml` to the `resources` property.
2. Modify the YAML in the `patch` property within the `infra/cluster/aws/machinesets.yaml` file to
   match your cluster's infrastructure ID and the networking/compute
   configuration in your VPC.
