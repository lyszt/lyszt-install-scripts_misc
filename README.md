# lyszt-install-scripts_misc

Open source installers for the RISC-V tools featured on the [LYSZT RISC-V ecosystem wiki](https://lyszt.net/en/academia/resources/riscv/ecosystem/ripes). One command, verified download, no sudo.

## Install

**Ripes** (graphical RISC-V architecture simulator):

```sh
curl -fsSL https://raw.githubusercontent.com/lyszt/lyszt-install-scripts_misc/main/install.sh | sh -s -- ripes
```

**RARS** (RISC-V Assembler and Runtime Simulator, requires Java 17+):

```sh
curl -fsSL https://raw.githubusercontent.com/lyszt/lyszt-install-scripts_misc/main/install.sh | sh -s -- rars
```

Windows users: grab the `.zip` from the tool's GitHub releases, or use the download dialog on its LYSZT wiki page.

## What the installer does

1. Resolves the latest release from the official GitHub repository of the tool.
2. Picks the right asset for your operating system and architecture.
3. Verifies the `sha256` digest that GitHub publishes for the asset — the install aborts on any mismatch.
4. Installs to `~/.local/bin` (Linux) or `~/Applications` (macOS), never touching system directories and never asking for sudo.
5. Tells you exactly what it installed and how to run it.

If the install directory is not on your `PATH`, the script prints the one-line fix.

## Options

| Option | Description |
| --- | --- |
| `--version <tag>` | Install a specific release tag (e.g. `v2.3.0`). Useful for courses, where every student should run the same version. |
| `--install-dir <dir>` | Target directory instead of the default `~/.local/bin`. |
| `-h`, `--help` | Usage summary. |

Examples:

```sh
# Pin a version for a course
sh install.sh rars --version v1.6

# Install somewhere else
sh install.sh ripes --install-dir ~/bin
```

## For instructors

`--version` exists so a whole class installs the exact same release. The script prints the installed tag, so lab reports can cite it. The scripts are plain POSIX `sh` with no dependencies beyond `curl` (or `wget`), so they behave the same on lab machines, student laptops, and remote servers.

## Security

- Read the script before running it — it is short, and that is the point. Piping to `sh` runs code from this repository; you should know what it does.
- Downloads always come from the tool's official GitHub releases, never from a mirror.
- Checksums are verified against GitHub's own published digests before anything is installed.
- No sudo, no system package changes, no telemetry. Everything lands in your home directory and is removed by deleting it.

## Contributing

Bug reports and PRs welcome, especially for distributions where an asset pattern or a Java detection case is wrong. Keep the scripts POSIX `sh` and dependency-free.

## License

[Apache-2.0](LICENSE). The tools themselves (Ripes, RARS, and others) are downloaded from their official releases and remain under their own licenses.
