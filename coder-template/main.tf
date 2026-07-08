# local-coder workspace template
#
# A plain CPU Docker workspace (no GPU passthrough) for driving Claude Code
# against the local ollama model server over the personal tailnet. The GPU
# lives on the host with ollama; workspaces stay light and reach the model
# over the network.
#
# Provisioning: on start, the workspace clones KaiNakamura/dotfiles and runs
# `./install.sh --profile coder` (the headless module subset, which installs
# Claude Code). Claude Code is pointed at ollama via the Anthropic-compatible
# API env vars below, so no router or shim is needed.
#
# Push to the local Coder server with:
#   coder templates push local-coder -d ./coder-template
#
# UNTESTED on real hardware: written to be ready for the 5070 desktop; verify
# on first real install (also confirms the values coder-server recorded in
# /etc/coder.d/coder.env: LOCAL_CODER_OLLAMA_URL, LOCAL_CODER_MODEL).
#
# Based on Coder's official Docker starter template:
# https://github.com/coder/coder/blob/main/examples/templates/docker/main.tf
# Adapted: dotfiles + ollama env wiring, model/branch parameters. The
# entrypoint replace() trick (rewrite localhost -> host.docker.internal) and
# the data sources are kept from the upstream template.

terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# --- Parameters --------------------------------------------------------------
# Defaults should match what coder-server recorded in /etc/coder.d/coder.env.
# They are mutable so they can be changed per workspace at start without a
# template re-push.
# TODO: the `model` default below duplicates DEFAULT_MODEL in
# coder-server/install.sh (Terraform can't read coder.env at push time).
# Consolidate to a single source of truth later, e.g. a push wrapper that reads
# coder.env and passes `--variable`. Fine while the model rarely changes.

variable "ollama_url" {
  description = "Tailnet URL of the host ollama server (e.g. http://100.x.y.z:11434 or http://<desktop-tailnet-name>:11434). Matches LOCAL_CODER_OLLAMA_URL from coder-server."
  type        = string
  # Set this to your desktop's tailnet endpoint when pushing the template.
  default = "http://localhost:11434"
}

data "coder_parameter" "model" {
  name         = "model"
  display_name = "Local model"
  description  = "Ollama model Claude Code uses (must be pulled on the host). Matches LOCAL_CODER_MODEL from coder-server."
  type         = "string"
  default      = "glm-4.7-flash"
  mutable      = true
  order        = 1
}

data "coder_parameter" "dotfiles_branch" {
  name         = "dotfiles_branch"
  display_name = "Dotfiles branch"
  description  = "Branch of KaiNakamura/dotfiles to provision the workspace from."
  type         = "string"
  default      = "main"
  mutable      = true
  order        = 2
}

# --- Agent -------------------------------------------------------------------

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Claude Code -> local ollama over the tailnet (Anthropic-compatible API).
  env = {
    ANTHROPIC_BASE_URL   = var.ollama_url
    ANTHROPIC_AUTH_TOKEN = "ollama"
    ANTHROPIC_API_KEY    = ""
    ANTHROPIC_MODEL      = data.coder_parameter.model.value
    # Convenience for shell use / verification.
    LOCAL_CODER_MODEL      = data.coder_parameter.model.value
    LOCAL_CODER_OLLAMA_URL = var.ollama_url
  }

  startup_script = <<-EOT
    set -e

    # Provision from personal dotfiles (headless coder profile installs Claude Code).
    if [ ! -d "$HOME/repos/dotfiles/.git" ]; then
      git clone --branch "${data.coder_parameter.dotfiles_branch.value}" \
        https://github.com/KaiNakamura/dotfiles "$HOME/repos/dotfiles"
    fi
    cd "$HOME/repos/dotfiles"
    git fetch origin "${data.coder_parameter.dotfiles_branch.value}" || true
    git checkout "${data.coder_parameter.dotfiles_branch.value}" || true
    git pull --ff-only || true
    ./install.sh --profile coder

    # Quick reachability check against the local model server.
    if curl -fsS "${var.ollama_url}/api/tags" >/dev/null 2>&1; then
      echo "local-coder: ollama reachable at ${var.ollama_url}"
    else
      echo "local-coder: WARNING ollama not reachable at ${var.ollama_url}" >&2
    fi
  EOT
}

# --- Compute -----------------------------------------------------------------

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_image" "main" {
  name         = "codercom/enterprise-base:ubuntu"
  keep_locally = true
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  # Run the Coder agent as the container entrypoint. The replace() rewrites
  # localhost/127.0.0.1 in the init script to host.docker.internal so the agent
  # inside the container can reach the Coder server on the host. (Verbatim from
  # the upstream Coder docker template; see header for source.)
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  hostname   = lower(data.coder_workspace.me.name)

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
}
