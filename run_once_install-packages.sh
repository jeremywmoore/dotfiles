#!/bin/bash
curl https://mise.run | sh
eval "$(~/.local/bin/mise activate bash)"
mise install
