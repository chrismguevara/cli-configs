# infra/terraform

Provisions one Oracle Linux 9 Always Free VM reachable only over SSH.

    cd infra/terraform
    cp terraform.tfvars.example terraform.tfvars   # edit: region, compartment, ssh key
    terraform init
    terraform plan
    terraform apply
    terraform output ssh_command

Authentication uses `~/.oci/config` (profile `DEFAULT`, created by `oci setup config`)
or the `TF_VAR_tenancy_ocid`, `TF_VAR_user_ocid`, `TF_VAR_fingerprint`,
`TF_VAR_private_key_path` environment variables. Nothing secret is stored in this
directory; `terraform.tfvars` and state are git-ignored.

Resources: VCN 10.42.0.0/16, public subnet 10.42.1.0/24, internet gateway,
route table, security list (ingress TCP/22 only, egress all), one instance with
`cloud-init.yaml` (key-only sshd, firewalld left at its SSH-only default).

Free-tier notes:
- `VM.Standard.A1.Flex` (ARM, default 2 OCPU / 12 GB = the Always Free ceiling
  published on oracle.com/cloud/free) is the practical choice; the x86_64
  `VM.Standard.E2.1.Micro` has 1 GB RAM. Every tool in this repo has an aarch64
  build (Neovim, Herdr, OpenCode, LazyGit, Go, Node, tree-sitter via cargo).
- Oracle reclaims *idle* Always Free instances (7 days below 20% CPU/network/
  memory) and keeps A1 instances only while the tenancy stays within the free
  allowance; a paid-tier upgrade removes both constraints.
- A1 capacity is often exhausted ("Out of host capacity"): retry later, or set
  `availability_domain_index` to another AD, or switch to the micro shape.
- Always Free compute must live in the tenancy's home region.

Tear down with `terraform destroy` (only touches resources in this state).
