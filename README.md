# lyszt-install-scripts_misc

Public mirror of the installer scripts used by [LYSZT](https://lyszt.net).

The canonical installer experience lives on the LYSZT website: each RISC-V tool's ecosystem page (for example [Ripes](https://lyszt.net/en/academia/resources/riscv/ecosystem/ripes)) and its download dialog serve the one-line install commands and the scripts themselves. This repository exists so those scripts are open, auditable, and versioned — you can read exactly what runs on your machine before you pipe it to `sh`.

This is not an independent project. Nothing here is installed or distributed directly from this repository; the code mirrors what LYSZT serves.

## Supported tools

- **Ripes** — graphical RISC-V computer architecture simulator
- **RARS** — RISC-V Assembler and Runtime Simulator (requires Java 17+)

To install either one, use the command published on the tool's page at lyszt.net. Windows users can use the download dialog on the same pages.

## What the installer does

The scripts served by LYSZT and mirrored here:

1. Resolve the latest release from the official GitHub repository of the tool.
2. Pick the right asset for your operating system and architecture.
3. Verify the `sha256` digest that GitHub publishes for the asset — the install aborts on any mismatch.
4. Install to `~/.local/bin` (Linux) or `~/Applications` (macOS), never touching system directories and never asking for sudo.
5. Print exactly what was installed and how to run it.

If the install directory is not on your `PATH`, the script prints the one-line fix.

## Options

| Option | Description |
| --- | --- |
| `--version <tag>` | Install a specific release tag (e.g. `v2.3.0`). Useful for courses, where every student should run the same version. |
| `--install-dir <dir>` | Target directory instead of the default `~/.local/bin`. |
| `-h`, `--help` | Usage summary. |

The installer also supports running a checkout locally for inspection:

```sh
sh install.sh <tool> [--version <tag>] [--install-dir <dir>]
```

## For instructors

`--version` exists so a whole class installs the exact same release. The script prints the installed tag, so lab reports can cite it. The scripts are plain POSIX `sh` with no dependencies beyond `curl` (or `wget`), so they behave the same on lab machines, student laptops, and remote servers.

## Security

- Read the script before running it — it is short, and that is the point. The mirror exists precisely so you can audit what the LYSZT one-liner runs.
- Downloads always come from the tool's official GitHub releases, never from a mirror of the binaries.
- Checksums are verified against GitHub's own published digests before anything is installed.
- No sudo, no system package changes, no telemetry. Everything lands in your home directory and is removed by deleting it.

## Mirroring

Changes land on LYSZT first and are mirrored here. PRs are welcome, both to change the existing scripts and to add new tools — the installer is built to take a new tool by adding its repository, asset patterns, and install steps. If you find a bug (an asset pattern that misses your distro, a Java detection case), open an issue or PR against this mirror and it will be reviewed and shipped through the site. Keep the scripts POSIX `sh` and dependency-free.

## License

[Apache-2.0](LICENSE). The tools themselves (Ripes, RARS, and others) are downloaded from their official releases and remain under their own licenses.
