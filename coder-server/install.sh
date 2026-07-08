#!/bin/bash
# coder-server module: turns this machine into a self-hosted Coder control
# plane, reachable over the personal tailnet.
#
# NOT part of any profile. Install explicitly on the server machine only:
#
#     ./install.sh coder-server
#
# Depends on the docker, coder, and ollama modules (invoked below; all are
# idempotent no-ops when already installed). Requires tailscale to be logged in
# first so the access URL and the ollama endpoint can be derived from the
# tailnet identity.
#
# Workspaces are Docker containers on this host, provisioned by Coder's
# Terraform Docker provider through the docker socket. They run Claude Code
# against the local ollama model server over the tailnet.

set -e

# The local coding model this server serves to workspaces. coder-server owns
# this choice; the ollama module is model-agnostic. DEFAULT_MODEL is recorded
# into /etc/coder.d/coder.env so the workspace template can default to the same
# value.
# TODO: DEFAULT_MODEL is duplicated as the `model` parameter default in
# coder-template/main.tf (Terraform can't read coder.env at push time).
# Consolidate to a single source of truth later, e.g. a push wrapper that reads
# coder.env and passes `--variable`. Fine while the model rarely changes.
# glm-4.7-flash (30B-A3B MoE): the model that actually drives Claude Code well.
# Non-fatal caveat: ~19GB, so it CPU-offloads on a 12GB card (tolerable, only 3B
# active). Small non-thinking coder models (qwen2.5-coder) were tested and could
# not hold agentic tool-calling even with a 64K context, so they are not served.
MODELS=("glm-4.7-flash")
DEFAULT_MODEL="glm-4.7-flash"

# Dependencies (idempotent)
(cd ../docker && bash install.sh)
(cd ../coder && bash install.sh)
(cd ../ollama && bash install.sh)

# Derive access URL from the tailnet IP (not DNS name: Docker containers can't
# resolve Tailscale hostnames without extra DNS config, so using the IP makes
# agent init scripts work inside containers without additional setup).
if ! command -v tailscale >/dev/null 2>&1; then
    echo "coder-server: tailscale not installed. Run \`./install.sh tailscale\` first." >&2
    exit 1
fi

ts_ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"

if [[ -z "$ts_ip" ]]; then
    echo "coder-server: not on a tailnet. Run \`sudo tailscale up\` first." >&2
    exit 1
fi

access_url="http://${ts_ip}:3000"
echo "coder-server: access URL will be $access_url"

# Configure the server. The deb package's coder.service reads env vars from
# /etc/coder.d/coder.env.
set_env_var() {
    local key="$1" value="$2" file="/etc/coder.d/coder.env"
    sudo mkdir -p /etc/coder.d
    sudo touch "$file"
    if sudo grep -q "^${key}=" "$file"; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
    fi
}

set_env_var CODER_ACCESS_URL "$access_url"
set_env_var CODER_HTTP_ADDRESS "0.0.0.0:3000"

# The ollama module bound the server to the tailnet IP. Workspaces reach it
# there; local clients (including the pulls below) must target the same address.
if [[ -z "$ts_ip" ]]; then
    echo "coder-server: could not derive tailnet IP for ollama; skipping model pull." >&2
else
    ollama_endpoint="http://${ts_ip}:11434"
    export OLLAMA_HOST="${ts_ip}:11434"

    # Wait for the ollama server to accept connections after the restart.
    echo "coder-server: waiting for ollama at $ollama_endpoint ..."
    for _ in $(seq 1 30); do
        if curl -fsS "$ollama_endpoint/api/tags" >/dev/null 2>&1; then break; fi
        sleep 1
    done

    # Pull the model(s) this server serves.
    for model in "${MODELS[@]}"; do
        echo "coder-server: pulling $model (this can take a while)"
        ollama pull "$model"
    done

    # Record the endpoint + default model so the workspace template can read
    # them (single source of truth lives here, not duplicated in the template).
    set_env_var LOCAL_CODER_OLLAMA_URL "$ollama_endpoint"
    set_env_var LOCAL_CODER_MODEL "$DEFAULT_MODEL"
fi

# Let the coder system user (created by the deb package) provision Docker
# workspaces through the socket.
if id coder >/dev/null 2>&1; then
    sudo usermod -aG docker coder
fi

sudo systemctl enable --now coder
sudo systemctl restart coder

echo ""
echo "coder-server: running. Next steps:"
echo "  1. Visit $access_url from any device on your tailnet"
echo "  2. Create the admin account"
echo "  3. Push the local-coder workspace template:"
echo "       coder login $access_url"
echo "       coder templates push local-coder -d ./coder-template"
echo "  4. Create a workspace from the local-coder template; Claude Code in it"
echo "     talks to ollama (model: ${DEFAULT_MODEL:-glm-4.7-flash}) over the tailnet."
echo "  5. From other machines: coder login $access_url"
