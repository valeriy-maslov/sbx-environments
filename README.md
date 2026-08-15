# sbx-environments

My personal collection of shared development environments for
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). This is not a
product or a project with a roadmap — just the setup I reuse across machines
so a new sandbox comes up with the tooling I expect.

Use it if it is helpful, but it is tuned to my preferences.

## Kits

Everything here is a kit: a `spec.yaml` mixin that attaches to whichever agent
you launch, rather than an image you have to build first. Kits are experimental,
and they run their install steps when the sandbox is created, which costs about
a minute for the full set.

This started as a Docker template and was replaced by kits, because a template
is a 5 GB image every machine has to rebuild, it is tied to one agent, and its
toolchains only worked in interactive shells.

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

`kits/vgm-zsh/files/home/.zshrc` and `.p10k.zsh` are my host dotfiles, minus the
macOS-specific parts (Homebrew paths, pyenv, LM Studio). The powerlevel10k
prompt expects a Nerd Font in the terminal you attach from.

Interactive bash hands over to zsh, so `sbx exec -it <sandbox> bash` lands in
zsh too. Non-interactive bash is left alone, which is what agents run.

## License

MIT — see [LICENSE](LICENSE).
