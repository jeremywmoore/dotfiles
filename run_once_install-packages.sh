# In your chezmoi source, create:
# run_once_install-packages.sh
#!/bin/bash
curl https://mise.run | sh
mise install
