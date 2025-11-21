> This is a rough draft of the demo script I used for recordings and
> presentation.
>
> Feel free to modify it to your needs!

## Demo Setup

- Screen 1, Side by Side
  - Side A
    - Tab 1: ACM hub in AWS
    - Tab 2: Example Todo App
    - Tab 3: AWS console
    - Tab 
  - Side B
    - Tab 1: ACM hub in GCP
- Screen 2: Split tmux panes - 1 top, 2 bottom
  - Top pane: vim (to enable the `apps` GitOps Kustomization on GCP)
  - Bottom pane:
    - Left pane: Failover script
    - Right pane: Watcher for Kustomizations and ManagedClusters
- Screen 3
  - Tab 1: AWS console
  - Tab 2: RHDP

## Script

- Intro
- Architecture
  - Primary hub in AWS, backup hub in GCP
  - Primary hub managing application clusters in AWS `us-east-2` and GCP `us-east1`
  - Both application clusters are running Portworx and are connected to each other with a cluster pair
  - Our example app is running in the application cluster in AWS but not in GCP (to save on resources)
- What we're going to do
  - Simulate disaster
    - Confirm that our primary ACM hub, backup ACM hub, Argo server and our app are working as intended
    - Jump into a terminal to confirm that our primary ACM hub is backing itself up and that the GitOps for our ACM infrastructure is working
    - Use Ansible to monitor for a regional outage and automatically perform a failover
    - Destroy `us-east-2` by shutting stuff off
    - Watch the failover script go!
    - Confirm that our backup ACM hub is now serving a primary role
    - Use GitOps to enable our application in the GCP cluster
    - Confirm that our app is still working
- Before we break things...
  - Everything you're looking at is managed by this repository
  - You can fork it, copy and modify this config.yaml and run this deploy script to deploy everything you'll see today
- Demo
  - Confirm (Screen 1)
    - Primary ACM hub
      - Managed clusters
      - Submariner
    - GitOps
      - Open from tile menu
      - Show applications; there should be five
    - Todo app
      - Add some todos
      - Cross some out
  - Jump (Screen 2)
    - Bottom-left: `oc get backup -A`
    - Bottom-right: `watch -n 0.5 oc get kustomization,clusterdeployment,managedcluster`
  - Ansible (Screen 2)
    - Bottom-left: `./failover.sh`, and now we wait
  - Destroy! (Screen 3)
    - RHDP: Turn off AWS OpenShift demo environment
    - AWS console: turn off all of the managed clusters
  - Watch (Screen 2)
    - Bottom left: Failover script should start moving now
    - Bottom-right: SSH into GCP and `watch -n 0.5 oc get kustomization,clusterdeployment,managedcluster`
  - Confirm (Screen 1)
    - Backup ACM hub
      - Managed clusters
      - Submariner
    - GitOps
      - Open from tile menu
      - Show applications; there should be five
  - Enable (Screen 2, Screen 1)
    - Screen 2: Remove `spec.suspend` from the `apps` Kustomimzation
    - Screen 2: Commit, save and push.
    - Screen 1: Go to Argo, wait for app to appear
  - Confirm app (Screen 1)
    - Screen 1: Refresh app; confirm todos are still there
