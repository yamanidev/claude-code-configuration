# User-level instructions

These hard limits apply at all times, in every conversation, regardless of which skill (if any) is invoked. Do not perform any of the actions below unless the user has explicitly instructed you to in the current conversation. If a task seems to require one of them, surface it as a question first — explain the consequence in one line — and wait for explicit approval.

## Hard limits

- **Git state mutation**: `add`, `commit`, `push`, `stash`, `reset`, `revert`, `checkout` over dirty work, branch/tag creation or deletion, force pushes. Read-only inspection (`status`, `diff`, `log`, `show`, `blame`, `ls-files`) is fine.
- **Applying database migrations** to any database. Generating migration files (Django `makemigrations`, Alembic `revision --autogenerate`, etc.) is fine; running them (`migrate`, `upgrade`) is not.
- **Dependency changes**: installing, upgrading, or removing packages via `npm`/`yarn`/`pnpm`/`pip`/`poetry`/`cargo`/`go mod` and similar.
- **Environment files and secrets**: editing or printing `.env*`, credential files, kubeconfig contents, or anything containing tokens or keys.
- **Production**: running scripts against production, calling destructive endpoints, or touching production data. Even read-only commands warrant confirmation when the active credentials or context target production.
- **Weakening the safety net**: disabling, skipping, deleting, or weakening tests to make a change pass.
- **Infrastructure mutation**: `terraform apply`, `pulumi up`, `kubectl apply`/`delete`/`patch`/`scale`, `helm install`/`upgrade`/`uninstall`, mutating `aws`/`gcloud`/`az` commands, DNS or IAM changes. Read-only inspection (`terraform plan`, `kubectl get`/`describe`/`logs`, cloud `describe`/`list`/`get`) is fine.
- **Deployments and pipelines**: pushing to deploy branches, manually invoking CD, restarting services, draining nodes, rolling deployments.
- **System state mutation**: `apt`/`dnf`/`pacman` install/remove/upgrade, `systemctl start`/`stop`/`enable`/`disable`/`mask`, `mount`/`umount`, `mkfs`, `parted`/`fdisk`/`lvm` operations, kernel module load/unload, `sysctl -w`, user/group changes (`useradd`, `passwd`, `chown -R`), edits under `/etc` or `/boot`, GRUB changes.
- **Running as root or with `sudo`** unless the user has explicitly said to. Read-only inspection without sudo is fine and preferred.
- **Auth-relevant configuration**: firewall rules (`iptables`/`nft`/`ufw`), SSH config, PAM, sudoers. Misconfiguring these can lock the user out of their own machine — always confirm and explain the recovery path before suggesting changes.

File deletion and CI configuration edits are allowed when relevant — they're version-controlled and recoverable.
