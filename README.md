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

## Kits

Kits are the direction this repo is moving in: the same tooling as the template,
but as `spec.yaml` mixins that attach to any agent instead of being baked into a
`claude-code` image. They are experimental, and they run their install steps when
the sandbox is created rather than ahead of time.

| Kit | Contents |
| --- | --- |
| `kits/vgm-python` | uv, CPython 3.13, `python` pointing at it |
| `kits/vgm-jvm` | SDKMAN, GraalVM CE 21.0.2 as the default JDK |
| `kits/vgm-node` | nvm, Node 22.21.1 as the default |
| `kits/vgm-zsh` | zsh as the login shell, oh-my-zsh, powerlevel10k, fzf |

They are independent, so take the ones you want:

```bash
sbx run --kit ./kits/vgm-python --kit ./kits/vgm-jvm \
        --kit ./kits/vgm-node --kit ./kits/vgm-zsh claude
```

The toolchain kits write their shell init to `/etc/sandbox-persistent.sh` and
`~/.zshenv`, so `python`, `java` and `node` resolve in non-interactive shells as
well — including the ones an agent runs. That is the part the template never got
right.

Sandboxes deny outbound network by default, so each kit declares the hosts its
installers reach. When something fails to install, `sbx policy log` names the
blocked host.

Attach one to a sandbox that already exists. Its container is recreated with the
kit appended, and workspace data and agent session state are preserved:

```bash
sbx kit add <sandbox> ./kits/vgm-python
```

Kit references can also be a ZIP, an OCI registry reference, or a git repository,
so the same kit works from a checkout or straight from GitHub. Before using one,
check it:

```bash
sbx kit validate ./kits/vgm-python
sbx kit inspect ./kits/vgm-python
```

## Shell configuration

`kits/vgm-zsh/files/home/.zshrc` and `.p10k.zsh` (and their copies in
`templates/vgm-sandbox/`) are my host dotfiles, minus the macOS-specific parts
(Homebrew paths, pyenv, LM Studio). The powerlevel10k prompt expects a Nerd Font
in the terminal you attach from.

Interactive bash hands over to zsh, so `sbx exec -it <sandbox> bash` lands in
zsh too. Non-interactive bash is left alone, which is what agents run.

## License

MIT — see [LICENSE](LICENSE).
