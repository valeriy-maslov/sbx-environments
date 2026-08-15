# sbx-environments

My personal collection of shared development environments for
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). This is not a
product or a project with a roadmap — just the setup I reuse across machines
so a new sandbox comes up with the tooling I expect.

Use it if it is helpful, but it is tuned to my preferences.

## Templates

### `templates/vgm-sandbox`

Built on `docker/sandbox-templates:claude-code-docker` (Ubuntu 26.04).

| Tool | Version | Notes |
| --- | --- | --- |
| uv | 0.12.5 | manages Python versions and venvs |
| Python | 3.13 | `python`; the system `python3` stays at 3.14 |
| SDKMAN | latest | JVM toolchain manager |
| Java | 21.0.2-graalce | GraalVM CE, set as the SDKMAN default |
| nvm | 0.40.6 | Node version manager |
| Node | 22.21.1 | set as the nvm default |
| Go | 1.26 | from the base image, `GOTOOLCHAIN=auto` |
| zsh | apt | login shell, with oh-my-zsh, powerlevel10k and fzf |

Versions are build args, so they can be overridden without editing the
Dockerfile:

```bash
docker build --build-arg JAVA_VERSION=21.0.12-graal -t vgm-sandbox:v1 templates/vgm-sandbox
```

## Usage

Build the image and export it as a tarball:

```bash
make vgm-sandbox
```

Load it into the sandbox runtime and start a sandbox. The runtime keeps its own
image store, so the tarball round trip is what keeps this working without a
registry:

```bash
sbx template load dist/vgm-sandbox-v1.tar
sbx run -t vgm-sandbox:v1 claude
```

`sbx run -t vgm-sandbox:v1 shell` opens zsh instead of an agent, and
`sbx exec -it <sandbox> zsh` attaches to a running one.

## Shell configuration

`templates/vgm-sandbox/zshrc` and `p10k.zsh` are copies of my host dotfiles,
minus the macOS-specific parts (Homebrew paths, pyenv, LM Studio). The
powerlevel10k prompt expects a Nerd Font in the terminal you attach from.

## License

MIT — see [LICENSE](LICENSE).
