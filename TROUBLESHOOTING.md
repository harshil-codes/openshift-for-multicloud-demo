# Troubleshooting

These are some common issues I've run into while provisioning and operating this
environment and how I fixed them.

## Deployment

### One of my managed clusters never becomes ready

If you're stuck here:

```
TASK [Wait an hour for 'managed-cluster-aws' to become ready in ACM hub 'aws'] ***
```

or here:

```
TASK [Wait an hour for 'managed-cluster-gcp' to become ready in ACM hub 'gcp'] ***
```

Then this likely means that a `ClusterDeployment` is stuck or has failed. Check
the `ClusterProvision` logs for the cloud that is failing to confirm this.

If this is your first time running the demo or have recently made a change to
`config.yaml`, do the following to make sure that your cloud credentials are
up-to-date in your primary ACM hub:

1. Run `deploy.sh --regenerate-secrets --secrets-only`, then commit and push
   your changes into your fork.
2. Open Argo and synchronize the `bootstrap-primary-acm-hub` Application to sync
   these changes into your cluster.
3. Delete any `build` Pods in the namespace your failing managed cluster is in
   (`managed-cluster-aws` for AWS; `managed-cluster-gcp` for GCP).

If errors persist, check the `ClusterProvision` logs for the cluster that is
failing to provision for any permissions errors or quotas being exceeded.

### `deploy.sh` fails after "Confirm that there's at least one ready Portworx API Service"

This usually happens when either:

- ArgoCD fails to sync the StorageCluster into one of the managed OpenShift
  clusters, or
- One of the Portworx `StorageCluster`s in the OpenShift clusters managed by ACM
  fails to initialize due to its underlying CSI failing to start. Make sure that
  the Sec

Have a look at the `managed-cluster-${CLOUD}-infra` ArgoCD Application and make
sure that the `StorageCluster` resource any associated Secrets are synced, like
shown below.

![](./static/images/troubleshooting/1-infra-in-sync.png)

If they are not, click the "Sync" button and sync anything that's out of sync.


### `deploy.sh` fails after trying to apply the Portworx license

The Portworx license might have expired. Run the command below:

```sh
license_key=$(sops decrypt --extract \
    '["common"]["datareplication"]["settings"]["credentials"]["license_key"]' \
    config.yaml)
oc --kubeconfig /tmp/managed/aws_kubeconfig -n portworx get pod \
    -l name=portworx \
    -o name |
    head -1 |
    xargs -I {} oc --kubeconfig /tmp/managed/aws_kubeconfig exec -n portworx {} -- \
    /opt/pwx/bin/pxctl license activate saas --key "$license_key"
```

The license is expired if this returns `No licenses found.`

**If you're a Red Hatter**, contact the Red Hat Partner team at Portworx to
obtain these keys. Once you retrieve them, use the command below to update the
config wtih your new key:

```sh
sops set config.yaml \
    '["common"]["datareplication"]["settings"]["credentials"]["license_key"]' \
    "$new_key"
```
