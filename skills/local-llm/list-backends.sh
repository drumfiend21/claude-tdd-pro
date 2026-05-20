#!/usr/bin/env bash
# X-4 lists supported local-LLM backends per architecture §16 X-4.
echo "local-llm-list-backends: backend=ollama url=http://localhost:11434" >&2
echo "local-llm-list-backends: backend=llama.cpp url=http://localhost:8080" >&2
echo "local-llm-list-backends: backend=lm-studio url=http://localhost:1234" >&2
