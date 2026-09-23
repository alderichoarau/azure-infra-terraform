# Own directory/state: this VM is a personal convenience (CI minutes), not part of the
# quiz app's dependency chain -- decoupled apply/destroy cycle, only ever meant to be
# applied against the prod subscription (see README.md).
terraform {
  cloud {
    organization = "alderic-hoarau"

    workspaces {
      name = "azure-runner-alderic-hoarau"
    }
  }
}
