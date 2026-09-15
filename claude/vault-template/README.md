# Vault Template

**This directory is a reference, not active config.** Nothing here is loaded into a Claude session. It is a template you copy from when creating a thoughts vault.

It exists so the known-good vault shape stays version-controlled here, with history, rather than living only inside whichever vault happens to be on disk.

## Contents

| File | What it is |
|---|---|
| `thoughts.md` | The vault's root description. Copy to the root of a new vault. This is the one place a vault's structure is described. |
| `templates/` | Shapes for each artifact type. Copy alongside `thoughts.md`. |

## How it gets used

`install.sh` copies this directory to `~/.claude/vault-template/` so it is available on any machine dotfiles is installed on.

**Installing dotfiles never writes into a vault.** Creating a vault is a deliberate act: copy `thoughts.md` and `templates/` into the new vault's root by hand. A vault's root description gets edited to fit that vault, and an installer that overwrote it would silently discard that work.

## Why the structure lives here and not in a rule

`thoughts.md` was previously `rules/shared-thoughts.md`. Anything in `rules/` is loaded into *every* session on the machine, including sessions that never touch a vault. As the vault's own root file it is read when it is relevant instead.

Skills that write to a vault carry intent only. They deliberately do not know paths, filenames, or numbering, which means the same skills work against a vault of a different shape. That only holds if each vault describes itself, which is `thoughts.md`'s job.

`rules/thoughts-vault.md` is the one always-on line that points here.
