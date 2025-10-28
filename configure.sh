#!/bin/bash

# This script automates the full VS Code configuration.
# It will:
#  1. Ask for your ROS 2 distro if it's not set.
#  2. Source the system ROS 2 environment.
#  3. Source your local workspace environment.
#  4. Activate the local Python virtual environment.
#  5. Run the Python setup script to update your config files.
#  6. Generate a GitHub Actions workflow for linting and testing.

echo "--- Starting ROS 2 VS Code Configuration ---"

# 1. Find ROS Distro
if [ -z "$ROS_DISTRO" ]; then
  echo "ROS_DISTRO is not set."
  read -p "Please enter your ROS 2 distro (e.g., kilted, humble): " ROS_DISTRO
  if [ -z "$ROS_DISTRO" ]; then
    echo "Error: No ROS distro provided. Exiting."
    exit 1
  fi
fi
echo "Using ROS Distro: $ROS_DISTRO"

# 2. Source System Environment
SYSTEM_SETUP="/opt/ros/$ROS_DISTRO/setup.bash"
if [ -f "$SYSTEM_SETUP" ]; then
  echo "Sourcing $SYSTEM_SETUP"
  source "$SYSTEM_SETUP"
else
  echo "Error: Could not find system setup file at $SYSTEM_SETUP"
  exit 1
fi

# 3. Source Local Workspace Environment
LOCAL_SETUP="install/setup.bash"
if [ -f "$LOCAL_SETUP" ]; then
  echo "Sourcing $LOCAL_SETUP"
  source "$LOCAL_SETUP"
else
  echo "Error: Could not find local setup file at $LOCAL_SETUP"
  echo "Have you built the workspace with 'colcon build'?"
  exit 1
fi

# 4. Activate Python Virtual Environment
# (This assumes the venv is in 'venv', matching your setup_env.sh default)
VENV_DIR="venv"
if [ -f "$VENV_DIR/bin/activate" ]; then
    echo "Activating Python virtual environment from $VENV_DIR..."
    source "$VENV_DIR/bin/activate"
else
    echo "Error: Virtual environment not found at $VENV_DIR/bin/activate."
    echo "Please run 'make setup' to create it first."
    exit 1
fi

# 5. Run the Python Config Script
echo "Running Python setup script..."
# This will now use the python3 from the venv, which has 'toml'
python3 setup_vscode.py "$ROS_DISTRO"

# 6. Detect Python version
echo "Detecting Python version..."
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
if [ -z "$PYTHON_VERSION" ]; then
  echo "Error: Could not detect Python version."
  exit 1
fi
echo "Using Python Version: $PYTHON_VERSION"

# 7. Generate GitHub Actions Workflow
echo "Generating GitHub Actions workflow at .github/workflows/lint.yml..."
mkdir -p .github/workflows
# Note: We use `cat << EOF` (unquoted) to allow shell variable substitution.
# This requires escaping all GitHub Actions variables (e.g., ${{...}} -> \${{...}})
cat << EOF > .github/workflows/lint.yml
name: Lint and Test

on: [push, pull_request]

# Define the ROS version as a variable for the whole workflow
env:
  ROS_DISTRO: $ROS_DISTRO

jobs:
  lint:
    runs-on: ubuntu-latest

    # Run the job inside a Docker container that already has ROS installed
    container:
      image: ros:$ROS_DISTRO-ros-base

    steps:
      - uses: actions/checkout@v4

      # Setup Python
      - uses: actions/setup-python@v5
        with:
          python-version: "$PYTHON_VERSION"

      # Cache the pip venv directory
      - name: Cache pip venv
        id: cache-pip
        uses: actions/cache@v4
        with:
          path: venv
          key: \${{ runner.os }}-pip-\${{ hashFiles('**/requirements.txt') }}
          restore-keys: |
            \${{ runner.os }}-pip-

      # Install dependencies
      - name: Install dependencies
        # Add shell: bash here
        shell: bash
        run: |
          # The ROS container automatically sources ROS, so rosdep is on the PATH.
          # Update rosdep sources first
          rosdep update

          # Now install project's specific ROS dependencies
          rosdep install --from-paths src --ignore-src -r -y

          # Install Python-specific packages
          python -m venv venv
          source venv/bin/activate # 'source' now works because we specified bash
          pip install --upgrade pip
          pip install -r requirements.txt

      # Run lint checks
      - name: Run lint and format checks with Ruff
        # Add shell: bash here
        shell: bash
        run: |
          # The ROS env is already sourced by the container.
          # We only need to activate our venv.
          source venv/bin/activate
          ruff format src --check
          ruff check src

      # Run tests
      - name: Run tests
        # Add shell: bash here
        shell: bash
        run: |
          source venv/bin/activate
          pytest
EOF

echo ""
echo "--- SUCCESS ---"
echo "Configuration complete."
echo "IMPORTANT: Please ctrl+shift+p and run 'Developer: Reload Window' in VS Code"
echo "for all changes to take effect."
echo "---------------"

