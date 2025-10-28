# GitHub Actions Workflow (CI)

This document describes the Continuous Integration (CI) workflow defined in `.github/workflows/lint.yml`.

---

## Overview

The "Lint and Test" workflow automatically runs on every push and pull request to ensure code quality, correct formatting, and that all tests pass. It is specifically designed to work in a ROS 2 environment by setting up the necessary overlays and dependencies.

---

## Workflow Triggers

The workflow is triggered on:

* **`push`**: Any `git push` to any branch.
* **`pull_request`**: Any new pull request or update to an existing pull request.

---

## `lint` Job

This is the only job in the workflow. It runs on an `ubuntu-latest` runner and uses a global environment variable (`ROS_DISTRO: kilted`) to manage the ROS version, making it easy to update.

### Key Features

* **Dual Caching**: The workflow is heavily optimized for speed.
    1.  **ROS Cache**: The `ros-tooling/setup-ros` action automatically caches the main ROS 2 binaries. The first run will take 5-10 minutes, but subsequent runs will restore ROS from the cache in seconds.
    2.  **Pip Cache**: The `actions/cache` step saves and restores the Python `venv` directory. This cache is keyed to the `requirements.txt` file, so `pip install` only runs if your dependencies have actually changed.

* **Dependency Separation**: The workflow correctly uses `rosdep` to install system-level ROS dependencies (like `ackermann-msgs`) and `pip` to install Python-specific tools (like `ruff`).

### Job Steps

1.  **Checkout Code**: Uses `actions/checkout@v4` to get a copy of the repository.
2.  **Setup Python**: Uses `actions/setup-python@v5` to install Python 3.11.
3.  **Setup ROS 2**: Uses `ros-tooling/setup-ros@v0.7` to install the ROS 2 distribution specified by the `ROS_DISTRO` variable (e.g., `kilted`).
4.  **Cache pip venv**: Caches the `venv` directory based on a hash of the `requirements.txt` file.
5.  **Install dependencies**: A multi-step process:
    * Sources the ROS 2 `setup.bash` file to make `rosdep` available.
    * Initializes `rosdep`.
    * Runs `rosdep install` to install system dependencies (like `ackermann-msgs`) defined in your `package.xml` files.
    * Creates the `venv` and runs `pip install -r requirements.txt` to install Python-specific tools.
6.  **Run lint and format checks**: Sources both the ROS and `venv` environments, then runs:
    * `ruff format src --check`: Fails the build if the code is not formatted correctly.
    * `ruff check src`: Fails the build if there are any linting errors.
7.  **Run tests**: Sources both environments and runs `pytest`.
