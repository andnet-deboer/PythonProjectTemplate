#!/usr/bin/env bash
set -e

echo "Setting up virtual environment..."

# Default venv directory
VENV_DIR=${1:-venv}
shift  # Shift the first argument so $@ now contains extras
EXTRAS="$@"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Virtual environment created at $VENV_DIR"
fi

# Activate it
source "$VENV_DIR/bin/activate"

# Upgrade pip
pip install --upgrade pip

# --- Build list of packages ---
# Use a temporary file to store the list of package names
REQS_TO_INSTALL=$(mktemp)

# Clean up the temp file on exit
trap 'rm -f $REQS_TO_INSTALL' EXIT

# Base packages
echo "setuptools" >> $REQS_TO_INSTALL
echo "jinja2" >> $REQS_TO_INSTALL
echo "typeguard" >> $REQS_TO_INSTALL
echo "pyyaml" >> $REQS_TO_INSTALL

# Default packages
echo "numpy" >> $REQS_TO_INSTALL
echo "scipy" >> $REQS_TO_INSTALL
echo "pandas" >> $REQS_TO_INSTALL
echo "matplotlib" >> $REQS_TO_INSTALL
echo "seaborn" >> $REQS_TO_INSTALL
echo "plotly" >> $REQS_TO_INSTALL
echo "click" >> $REQS_TO_INSTALL
echo "tqdm" >> $REQS_TO_INSTALL
echo "scikit-learn" >> $REQS_TO_INSTALL

# Dev packages
echo "ruff" >> $REQS_TO_INSTALL
echo "flake8" >> $REQS_TO_INSTALL
echo "isort" >> $REQS_TO_INSTALL
echo "pytest" >> $REQS_TO_INSTALL
echo "mypy" >> $REQS_TO_INSTALL
echo "pre-commit" >> $REQS_TO_INSTALL

# Process extras
for extra in $EXTRAS; do
    case "$extra" in
        ros)
            echo "rosdep" >> $REQS_TO_INSTALL
            ;;
        ai--tensorflow) echo "tensorflow" >> $REQS_TO_INSTALL ;;
        ai--pytorch)
            echo "torch" >> $REQS_TO_INSTALL
            echo "torchvision" >> $REQS_TO_INSTALL
            echo "torchaudio" >> $REQS_TO_INSTALL
            ;;
        ai--keras) echo "keras" >> $REQS_TO_INSTALL ;;
        *) echo "Warning: unknown extra '$extra', skipping" >&2 ;; # Send warning to stderr
    esac
done

# --- Install all packages at once ---
echo "Installing/updating packages..."
pip install -r $REQS_TO_INSTALL

# --- Generate requirements.txt ---
echo "Generating requirements.txt..."
pip freeze --local > requirements.txt
