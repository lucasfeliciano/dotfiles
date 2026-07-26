# Ubuntu 26.04 amd64

Ubuntu support targets Ubuntu 26.04 on amd64 hardware.

## Base profile

The base APT inventory contains exactly these 20 packages:

```text
zsh
git
curl
wget
ca-certificates
gnupg
build-essential
shellcheck
jq
fzf
ripgrep
fd-find
bat
eza
tmux
btop
tree
unzip
7zip
ghostty
```

The base Snap inventory is `code --classic`. The package module invokes the official mise installer only when mise is absent.

The complete base profile is `packages zsh eza mise ghostty git`.

## Networking profile

The networking profile installs eight diagnostic packages:

```text
iproute2
iputils-ping
dnsutils
netcat-openbsd
tcpdump
traceroute
mtr-tiny
whois
```

It changes no interfaces, routes, DNS, firewall, services, or probes.

## Virtualization profile

The virtualization profile installs nine packages:

```text
qemu-system-x86
qemu-utils
libvirt-daemon-system
libvirt-clients
virt-manager
virt-viewer
ovmf
swtpm
cpu-checker
```

It adds the current user to the `libvirt` and `kvm` groups, enables and starts `libvirtd.service`, and ensures that the default network is active, autostarting, and uses NAT. It also ensures that `vm-isolated` is active and autostarting on `192.168.77.0/24`, with DHCP and no forwarding.

No image is downloaded and no VM is created.

## Composing profiles

Optional profiles include the base profile automatically and compose in canonical order:

```sh
./setup.sh --profile networking
./setup.sh --profile virtualization
./setup.sh --profile virtualization networking
```

## Applying login-shell and group changes

Log out and back in after setup changes the login shell or group membership. A reboot applies both changes as well. Until then, the new shell and `libvirt`/`kvm` membership may not be visible to the current session.

## Verification

Use check mode for the corresponding read-only repository checks:

```sh
./setup.sh --check --profile networking
./setup.sh --check --profile virtualization
./setup.sh --check --profile virtualization networking
```

For a generic read-only view of system libvirt networks, run:

```sh
virsh -c qemu:///system net-list --all
```

A logout or reboot is required before new sessions observe login-shell and group changes. Check mode verifies active `libvirt`/`kvm` group membership; it does not inspect the configured login shell.
