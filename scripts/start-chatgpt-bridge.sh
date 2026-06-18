#!/bin/bash

exec python3 \
    $HOME/Dev/Configuration/Agents/scripts/chat-gpt-local-bridge.py \
    --root "$HOME/Dev/ChatGPT Repo"
