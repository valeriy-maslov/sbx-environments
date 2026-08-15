ARG BASE_TAG=claude-code-docker

FROM docker/sandbox-templates:${BASE_TAG}

ARG UV_VERSION=0.12.5
ARG PYTHON_VERSION=3.13
ARG JAVA_VERSION=21.0.2-graalce
ARG NVM_VERSION=0.40.6
ARG NODE_VERSION=22.21.1

USER root

# refresh repositories and upgrade all pre-installed packages
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && apt-get autoremove -y

# sdkman prerequisite (unzip/curl/sed already present in the base image)
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y zip

# zsh + fzf (fzf backs the oh-my-zsh plugin of the same name)
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y zsh fzf \
    && chsh -s /bin/zsh agent

# system-level setup (apt packages, global binaries)

USER agent

# uv: python version + venv manager (avoids PEP 668 on the system python)
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh \
    && uv python install ${PYTHON_VERSION} \
    && ln -s python${PYTHON_VERSION} /home/agent/.local/bin/python

# sdkman: jvm toolchain manager
RUN curl -s "https://get.sdkman.io" | bash

# jdk (sdkman requires bash and an explicitly sourced init script)
RUN bash -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk install java '"${JAVA_VERSION}"

# the base image points npm at an (empty) global prefix, which nvm refuses to run with
ENV NPM_CONFIG_PREFIX=

# nvm: node version manager
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash

# node (NVM_DIR is only exported by .bashrc, so point at it explicitly;
# NPM_CONFIG_PREFIX comes from the base image and nvm refuses to run with it set)
RUN bash -c 'unset NPM_CONFIG_PREFIX && source "$HOME/.nvm/nvm.sh" && nvm install '"${NODE_VERSION}"' && nvm alias default '"${NODE_VERSION}"

# oh-my-zsh + powerlevel10k (the installer's own .zshrc is replaced by ours below)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
       /home/agent/.oh-my-zsh/custom/themes/powerlevel10k

COPY --chown=agent:agent zshrc /home/agent/.zshrc
COPY --chown=agent:agent p10k.zsh /home/agent/.p10k.zsh

# user-level setup (rustup, dotfiles)
