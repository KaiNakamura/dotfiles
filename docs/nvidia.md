# NVIDIA Setup

## Driver Installation

Download and install the driver from <https://www.nvidia.com/en-us/drivers/>.

```bash
chmod +x NVIDIA-Linux-x86_64-*.run
sudo ./NVIDIA-Linux-x86_64-*.run
```

## Container Toolkit (Docker)

Follow the install guide at <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>.

## Fix Suspend/Resume (Monitors Going Black)

The `nvidia-kernel-common` package ships systemd services required for suspend/resume, but they can go missing (package corruption). Without them, NVIDIA blocks suspend, which can leave USB-C docks and displays in a broken state.

Check if the services are missing:

```bash
dpkg --verify nvidia-kernel-common
```

If files are listed as missing, reinstall and enable:

```bash
sudo apt-get install --reinstall nvidia-kernel-common
sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate nvidia-suspend-then-hibernate
```

Verify:

```bash
systemctl is-enabled nvidia-suspend nvidia-resume nvidia-hibernate
# Should all say "enabled"
```

After a reboot, test with `systemctl suspend` and check logs:

```bash
journalctl -k --since "5 minutes ago" | grep -i nvidia
```
