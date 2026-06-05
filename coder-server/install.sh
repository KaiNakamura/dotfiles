#!/bin/bash
# coder-server module: turns this machine into a self-hosted Coder control
# plane, reachable over the personal tailnet.
#
# NOT part of any profile. Install explicitly on the server machine only:
#
#     ./install.sh coder-server
#
# Depends on the docker and coder modules (invoked below; both are idempotent
# no-ops when already installed). Requires tailscale to be logged in first so
# the access URL can be derived from the tailnet hostname.
#
# Workspaces are Docker containers on this host, provisioned by Coder's
# Terraform Docker provider through the docker socket.

set -e

# Dependencies (idempotent)
(cd ../docker && bash install.sh)
(cd ../coder && bash install.sh)

# Derive access URL from the tailnet hostname
if ! command -v tailscale >/dev/null 2>&1; then
    echo "coder-server: tailscale not installed. Run \`./install.sh tailscale\` first." >&2
    exit 1
fi

dns_name="$(tailscale status --json 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"

if [[ -z "$dns_name" ]]; then
    echo "coder-server: not on a tailnet. Run \`sudo tailscale up\` first." >&2
    exit 1
fi

access_url="http://${dns_name}:3000"
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
echo "  3. Create a Docker template (Templates -> Starter Templates -> Docker Containers)"
echo "  4. From other machines: coder login $access_url"
