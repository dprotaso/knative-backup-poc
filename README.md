### Knative Backup and Restore POC

This code highlights how it might be possible to perform a backup
and restore of Knative resources.

The tl;dr is 

- When restoring just install the Serving CRDs
- Backup your resources in order of ownership (parents first)
- Restore your resources using the ./cmd/restore go binary
- Install Serving Webhooks & Controllers

The POC tool updates owner references properly to preserve the
relationship between resources. This is required by Knative.
