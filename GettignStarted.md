# Getting Started with This Python Project Template

> Note: This file is for local setup instructions only. You can safely add it to `.gitignore`.

---

## Project Structure

* `src/` – Your Python source code.
* `setup_env.sh` – Script to create a virtual environment and install default/dev dependencies.
* `Makefile` – Simplifies common tasks like setting up the environment and cleaning.
* `.vscode/settings.json` – VS Code configuration for auto-formatting with Ruff.
* `requirements.txt` – Tracks installed Python packages.
* `.gitignore` – Files and folders ignored by git (e.g., `venv/`, `.vscode/`).

---

## Steps
1. Clone the repository:

```bash
git clone <your-repo-url>
cd <your-repo-directory>
```


2. Setting Up the Project

### Bootstrapping Environment

Use the Makefile to simplify environment setup:

```bash
make setup
```

This command will:

* Create a virtual environment (`venv`) if it does not exist.
* Install default Python packages (numpy, pandas, matplotlib, etc.).
* Install development tools (Ruff, flake8, isort, mypy, pytest, pre-commit).
* Optionally install extras (AI frameworks, ROS) if specified via `EXTRA`:

```bash
make setup ai--tensorflow
make setup ai--pytorch
make setup ros
```
You can **combine** multiple arguments like ```make setup ros ai--tensorflow```

After running, activate the environment:

```bash
source venv/bin/activate
```

### Cleaning the Environment

```bash
make clean
```

Removes the virtual environment.

---

## Using VS Code

1. Open the project folder in VS Code.
2. Install the Ruff extension: [Ruff](https://marketplace.visualstudio.com/items?itemName=charliermarsh.ruff)
3. The project is preconfigured via `.vscode/settings.json` to:

   * Format code on save
   * Organize imports
   * Use Ruff as the default Python formatter
4. Ensure VS Code uses the correct Python interpreter (`venv`).

---

## Running Tests and Linting

* Run tests:

```bash
pytest
```

* Check linting and formatting:

```bash
ruff check src/
ruff format src/  # auto-format code
```

---

## Adding New Dependencies

After installing new packages, update `requirements.txt`:

```bash
pip freeze > requirements.txt
```

---

This setup provides a consistent development environment and clear workflow for new contributors.
