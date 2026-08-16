# sbx-environments

My personal collection of shared development environments for
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/). This is not a
product or a project with a roadmap — just the setup I reuse across machines
so a new sandbox comes up with the tooling I expect.

Use it if it is helpful, but it is tuned to my preferences.

## Quick start

Create a sandbox with all of the kits attached, without checking anything out:

```bash
curl -fsSL https://raw.githubusercontent.com/valeriy-maslov/sbx-environments/master/scripts/vgm-sandbox.sh | sh
```

It defaults to `claude` in the current directory. Pass an agent and a workspace
to change that, and set `VGM_SANDBOX_NAME` to name the sandbox:

```bash
curl -fsSL https://raw.githubusercontent.com/valeriy-maslov/sbx-environments/master/scripts/vgm-sandbox.sh \
  | sh -s -- codex ~/Projects/thing
```

The script creates the sandbox and prints the `sbx run --name ...` command to
attach, rather than attaching itself: piping into `sh` takes over stdin, which
an interactive agent needs.

## Kits

Everything here is a kit: a `spec.yaml` mixin that attaches to whichever agent
you launch, rather than an image you have to build first. Kits are experimental,
and they run their install steps when the sandbox is created, which costs about
a minute for the full set.

This started as a Docker template and was replaced by kits, because a template
is a 5 GB image every machine has to rebuild, it is tied to one agent, and its
toolchains only worked in interactive shells.

| Kit | Kind | Contents |
| --- | --- | --- |
| `kits/vgm-python` | mixin | uv, CPython 3.13, `python` pointing at it |
| `kits/vgm-jvm` | mixin | SDKMAN, GraalVM CE 21.0.2 as the default JDK |
| `kits/vgm-node` | mixin | nvm, Node 22.21.1 as the default |
| `kits/vgm-zsh` | mixin | zsh as the login shell, oh-my-zsh, powerlevel10k, fzf |
| `kits/vgm-ralphex` | mixin | [ralphex](https://github.com/umputun/ralphex), autonomous plan execution, plus fzf |
| `kits/vgm-context7` | mixin | [Context7](https://github.com/upstash/context7) CLI, MCP server and skill for Claude Code |
| `kits/pi` | sandbox | the [pi](https://pi.dev/) coding agent, which sbx has no built-in agent for |

The mixins are independent, so take the ones you want:

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

## GitHub authentication

`gh` ships in the base images already. Log it into sbx's built-in `github`
secret service on the host, so the token never enters the sandbox:

```bash
echo "$(gh auth token)" | sbx secret set github
```

## Context7

`kits/vgm-context7` installs the [Context7](https://github.com/upstash/context7)
CLI and registers its MCP server and skill for Claude Code:

```bash
sbx run --kit ./kits/vgm-context7 claude
```

The kit ships no credentials. Without a key, the install step logs a notice and
skips registration rather than failing the sandbox; get a free key at
[context7.com/dashboard](https://context7.com/dashboard) and set it up on the
host with `sbx secret set-custom`, so it never enters the sandbox directly:

```bash
sbx secret set-custom \
  --host mcp.context7.com --host api.context7.com --host context7.com \
  --env CONTEXT7_API_KEY --value YOUR_KEY
```

Once that secret exists, new sandboxes created with this kit see
`CONTEXT7_API_KEY` set to a placeholder and run
`ctx7 setup --claude --api-key "$CONTEXT7_API_KEY"` automatically; the proxy
swaps the placeholder for the real key on outbound requests to the hosts above.
For a sandbox created before the secret was set, run that command by hand.

## ralphex

`kits/vgm-ralphex` installs [ralphex](https://github.com/umputun/ralphex), which
executes a markdown plan autonomously by driving fresh Claude Code sessions and
then reviewing the result. It drives the `claude` CLI, so pair it with the claude
agent:

```bash
sbx run --kit ./kits/vgm-ralphex claude
```

It installs the release binary for the sandbox's architecture rather than using
`go install`, so it does not need a Go toolchain in the base image. fzf comes
along too, since that is what ralphex uses to pick a plan.

Plans live in `docs/plans/`, and config in `.ralphex/` in the repository root,
falling back to `~/.config/ralphex/`.

## The pi agent

`kits/pi` is a sandbox kit rather than a mixin, because it defines an agent sbx
does not ship. It installs pi from `https://pi.dev/install.sh` onto the
`shell-docker` template, which already has the Node 22.19+ that pi's installer
requires. Start it with the kit name as the agent:

```bash
sbx run --kit ./kits/pi pi
```

Stack the toolchain mixins onto it like any other agent:

```bash
sbx run --kit ./kits/pi --kit ./kits/vgm-python --kit ./kits/vgm-zsh pi
```

### Giving pi an OpenRouter token

The kit ships no credentials — bring your own key from
[openrouter.ai/keys](https://openrouter.ai/keys). Two ways to hand it over.

Store it on the host, where sbx's proxy holds it and the sandbox never sees the
value. `openrouter` is one of sbx's built-in secret services:

```bash
echo "$OPENROUTER_API_KEY" | sbx secret set openrouter
```

Or authorize from inside the running agent, which mints a key billed against
your OpenRouter credits and writes it to `~/.pi/agent/auth.json` in the sandbox:

```
/login openrouter
```

Either way `openrouter.ai:443` is already allowed by the kit. Pick a model with
`--provider openrouter --model <model-id>`, or `/model` mid-session. Pi reads
`OPENROUTER_API_KEY` if you would rather set the variable yourself, but then the
key does live inside the sandbox.

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
