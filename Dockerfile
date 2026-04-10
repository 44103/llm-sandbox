FROM ubuntu:22.04

# 必要なパッケージをインストール
RUN apt-get update && apt-get install -y \
    curl \
    vim \
    zsh \
    ca-certificates \
    git \
    jq \
    locales \
    && locale-gen ja_JP.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=ja_JP.UTF-8

# Node.jsをインストール（MCPサーバー用）
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Kiro CLIをインストール
RUN curl -fsSL https://kiro.dev/install.sh | sh

# PATHにKiro CLIを追加
ENV PATH="/root/.local/bin:${PATH}"

RUN curl -fsSL https://raw.githubusercontent.com/44103/dotfiles/main/install.sh | zsh

# デフォルトのエントリーポイント
CMD ["/bin/zsh"]
