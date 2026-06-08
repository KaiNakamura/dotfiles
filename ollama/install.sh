#!/bin/bash
# ollama module: installs the ollama model runtime and binds it so other
# machines on the personal tailnet can reach it.
#
# Runtime only, model-agnostic: this module installs the engine and configures
# the listen address. It does NOT pull any model. Choosing which model to serve
# is a policy decision owned by the consumer (the coder-server module pulls the
# model the local coding workspaces use).
#
# Bind address: ollama listens on the tailnet IP (port 11434) so workspaces and
# other personal machines can reach it, without exposing it on every interface.
# If the host is not on a tailnet yet, it falls back to 0.0.0.0 with a warning;
# re-run after `sudo tailscale up` to tighten the bind.
#
# Because the server binds to the tailnet IP (not loopback), local clients must
# point at that address too: `OLLAMA_HOST=<tailnet-ip>:11434 ollama <cmd>`.

set -e

# Install the engine (idempotent). The official script creates the `ollama`
# systemd service and the `ollama` system user.
if command -v ollama >/dev/null 2>&1; then
    echo "ollama: already installed ($(ollama --version 2>/dev/null | head -1))"
else
    case "$(uname -s)" in
        Linux)
            echo "ollama: installing via official script"
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
        *)
            echo "ollama: $(uname -s) host, skipping (install manually)" >&2
            exit 0
            ;;
    esac
fi

# Derive the bind address from the tailnet IP when available.
ts_ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"
if [[ -n "$ts_ip" ]]; then
    bind_addr="$ts_ip"
    echo "ollama: binding to tailnet IP $bind_addr:11434"
else
    bind_addr="0.0.0.0"
    echo "ollama: not on a tailnet, binding to 0.0.0.0:11434 (broad)." >&2
    echo "ollama: run \`sudo tailscale up\` then re-run this module to tighten the bind." >&2
fi

# Configure the listen address via a systemd drop-in (idempotent: regenerated
# each run). The official unit reads OLLAMA_HOST from the environment.
if command -v systemctl >/dev/null 2>&1; then
    drop_in_dir="/etc/systemd/system/ollama.service.d"
    sudo mkdir -p "$drop_in_dir"
    printf '[Service]\nEnvironment="OLLAMA_HOST=%s:11434"\n' "$bind_addr" \
        | sudo tee "$drop_in_dir/override.conf" >/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable --now ollama
    sudo systemctl restart ollama
else
    echo "ollama: no systemd; set OLLAMA_HOST=$bind_addr:11434 and start ollama manually." >&2
fi

echo ""
echo "ollama: runtime ready. Verify with:"
echo "  curl http://$bind_addr:11434/api/tags"
echo "ollama: no model is pulled by this module (coder-server owns model choice)."
