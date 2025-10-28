#!/usr/bin/env python3

"""
Automatically configures the VS Code settings for a ROS 2 workspace.

It is designed to be called by the 'configure.sh' script, which sources the
environment and passes the ROS_DISTRO as a command-line argument.

It performs THREE main actions:
1.  **Sets Python Interpreter:**
    Finds the path to the current Python interpreter (which should be from
    the venv) and sets it as the 'python.defaultInterpreterPath' in
    '.vscode/settings.json'.

2.  **Fixes Pylance (Type Checking):**
    Finds all 'site-packages' directories from the system ROS 2 installation
    and the local workspace 'install' directory. It writes these paths to
    '.vscode/settings.json' under 'python.analysis.extraPaths'.
    This solves Pylance errors like 'reportAttributeAccessIssue' (e.g., "Cannot
    access attribute 'append' for class 'Sequence[Unknown]'").

3.  **Fixes Ruff (Linting):**
    Finds all local packages in the workspace 'install' directory (e.g.,
    'turtle_brick', 'turtle_brick_interfaces') and adds them to
    'pyproject.toml' under '[tool.ruff.lint.isort].known-first-party'.
    This solves Ruff import sorting errors like 'I201' (Missing newline
    between import groups).

REQUIREMENTS:
    - `pip install toml` (for reading/writing pyproject.toml)

USAGE:
    This script is intended to be run by 'configure.sh'.
    Example: `python3 setup_vscode.py kilted`
"""

import json
import os
import sys
from pathlib import Path

import toml


def get_python_version_string():
    """Get the 'pythonX.Y' string, e.g., 'python3.12'."""
    return f'python{sys.version_info.major}.{sys.version_info.minor}'


def find_paths_and_packages(workspace_root, python_version, ros_distro):
    """Find all Python paths including ROS 2 message types."""
    python_paths = []
    local_packages = []

    # Add system ROS 2 Python path
    if ros_distro:
        # Base ROS 2 Python path
        base_ros_path = Path(
            f'/opt/ros/{ros_distro}/lib/python\
                             {sys.version_info.major}.{sys.version_info.minor}]\
                             /site-packages'
        )
        if base_ros_path.is_dir():
            python_paths.append(str(base_ros_path))
            print(f'Found base ROS path: {base_ros_path}')

        # Also check dist-packages
        dist_packages_path = Path(
            f'/opt/ros/{ros_distro}/lib/python\
                                  {sys.version_info.major}.\
                                    {sys.version_info.minor}/dist-packages'
        )
        if dist_packages_path.is_dir():
            python_paths.append(str(dist_packages_path))
            print(f'Found ROS dist-packages: {dist_packages_path}')

        # Add the lib/python3.xx/site-packages from system ROS
        system_site_packages = Path(
            f'/opt/ros/\{ros_distro}/lib/{python_version}/site-packages'
        )
        if system_site_packages.is_dir():
            python_paths.append(str(system_site_packages))
            print(f'Found system site-packages: {system_site_packages}')
    else:
        print('Warning: ROS_DISTRO not set. System paths will be missing.')

    # Add local workspace paths
    install_dir = workspace_root / 'install'
    if not install_dir.is_dir():
        print(f"Error: 'install' directory not found at {install_dir}")
        print("Please build your workspace first (e.g., 'colcon build')")
        return [], []

    for package_dir in install_dir.iterdir():
        if not package_dir.is_dir():
            continue

        # Add package name for Ruff
        local_packages.append(package_dir.name)

        # Add multiple possible Python paths for Pylance
        possible_paths = [
            package_dir / f'lib/{python_version}/site-packages',
            package_dir
            / f'lib/python\
            {sys.version_info.major}.{sys.version_info.minor}/site-packages',
            package_dir / 'lib',
        ]

        for possible_path in possible_paths:
            if possible_path.is_dir():
                python_paths.append(str(possible_path))
                print(f'Found local path: {possible_path}')

    # Add any paths from PYTHONPATH environment variable
    python_path_env = os.environ.get('PYTHONPATH', '')
    if python_path_env:
        for path in python_path_env.split(':'):
            if path and Path(path).is_dir():
                python_paths.append(path)
                print(f'Found PYTHONPATH: {path}')

    # De-duplicate paths while preserving order
    seen = set()
    unique_paths = []
    for path in python_paths:
        if path not in seen:
            seen.add(path)
            unique_paths.append(path)

    unique_packages = sorted(list(set(local_packages)))

    print(f'\nFound {len(unique_packages)} local packages for Ruff.')
    print(f'Found {len(unique_paths)} Python paths for Pylance.')

    # Debug: Print all paths
    print('\nPython paths that will be added to Pylance:')
    for path in unique_paths:
        print(f'  - {path}')

    return unique_paths, unique_packages


def update_vscode_settings(workspace_root, python_paths, interpreter_path):
    """Update .vscode/settings.json with all necessary Python paths."""
    settings_dir = workspace_root / '.vscode'
    settings_dir.mkdir(exist_ok=True)
    settings_file = settings_dir / 'settings.json'

    settings_data = {}
    if settings_file.exists():
        try:
            with settings_file.open('r') as f:
                settings_data = json.load(f)
        except json.JSONDecodeError:
            print(f"Warning: '{settings_file}' is corrupted. Overwriting.")
            settings_data = {}

    # Set the default interpreter to the one from venv
    settings_data['python.defaultInterpreterPath'] = interpreter_path

    # Add Pylance/AutoComplete paths for ROS 2
    settings_data['python.analysis.extraPaths'] = python_paths
    settings_data['python.autoComplete.extraPaths'] = python_paths

    settings_data['python.analysis.typeCheckingMode'] = 'basic'
    settings_data['python.analysis.diagnosticMode'] = 'openFilesOnly'

    settings_data['cmake.configureOnOpen'] = False

    # Write the settings back
    try:
        with settings_file.open('w') as f:
            json.dump(settings_data, f, indent=2)
        print(f"Successfully updated '{settings_file}'")
    except Exception as e:
        print(f"Error writing to '{settings_file}': {e}")


def update_pyproject_toml(workspace_root, local_packages):
    """Update pyproject.toml with [tool.ruff.lint.isort].known-first-party."""
    toml_file = workspace_root / 'pyproject.toml'

    if not toml_file.exists():
        print(f"Error: 'pyproject.toml' not found at {workspace_root}")
        print('Ensure this script is in the same directory as pyproject.toml')
        return

    try:
        # Read existing TOML data
        with toml_file.open('r') as f:
            toml_data = toml.load(f)

        # --- Safely navigate and create keys if they don't exist ---
        tool_section = toml_data.setdefault('tool', {})
        ruff_section = tool_section.setdefault('ruff', {})
        lint_section = ruff_section.setdefault('lint', {})
        isort_section = lint_section.setdefault('isort', {})

        # Get existing list, or an empty one
        known_first_party = isort_section.get('known-first-party', [])

        # --- Add new packages and de-duplicate ---
        # This preserves any packages you added manually
        updated_list = sorted(list(set(known_first_party + local_packages)))

        # Write the updated list back
        isort_section['known-first-party'] = updated_list

        # Write the data back to the file
        with toml_file.open('w') as f:
            toml.dump(toml_data, f)

        print(f"Successfully updated '{toml_file}'")

    except Exception as e:
        print(f"Error processing '{toml_file}': {e}")


def main():
    """Run the configuration."""
    print('--- Python VS Code Configurator ---')

    # 1. Get ROS_DISTRO from command-line argument
    if len(sys.argv) < 2:
        print('Error: Missing ROS_DISTRO argument.')
        print("This script should be called by 'configure.sh'.")
        sys.exit(1)

    ros_distro = sys.argv[1]
    print(f'Using ROS_DISTRO: {ros_distro}')

    # 2. Get other paths and versions
    workspace_root = Path.cwd()
    python_version = get_python_version_string()

    # Get the full path to the currently running Python interpreter
    # (This will be from the venv if configure.sh activated it)
    interpreter_path = sys.executable
    print(f'Using Python interpreter: {interpreter_path}')

    print(f'Workspace root: {workspace_root}')
    print(f'Python version: {python_version}\n')

    # 3. Find all paths and packages
    python_paths, local_packages = find_paths_and_packages(
        workspace_root, python_version, ros_distro
    )

    if not python_paths and not local_packages:
        print('No packages found. Exiting.')
        sys.exit(1)

    # --- REMOVED CMAKE CHECKS ---
    print('Skipping CMake-specific settings.')

    # 4. Update Pylance config
    if python_paths:
        # Pass the interpreter_path to the settings function
        update_vscode_settings(workspace_root, python_paths, interpreter_path)

    # 5. Update Ruff config
    if local_packages:
        update_pyproject_toml(workspace_root, local_packages)

    print('\nPython script finished.')


if __name__ == '__main__':
    main()
