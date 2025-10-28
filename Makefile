.PHONY: setup clean

# Default Python venv directory
VENV_DIR := venv

# Extract extras from Make goals, skipping 'setup'
EXTRAS := $(filter-out setup,$(MAKECMDGOALS))

# Check if 'ros' is in the extras
ROS_ENABLED := $(if $(filter ros,$(EXTRAS)),true,)

setup:
	@echo "Bootstrapping Python environment..."
	@chmod +x setup_env.sh
	@if [ -n "$(EXTRAS)" ]; then \
		bash setup_env.sh $(VENV_DIR) $(EXTRAS); \
	else \
		bash setup_env.sh $(VENV_DIR); \
	fi
	@echo "Python environment setup complete."
	@echo ""
	@if [ "$(ROS_ENABLED)" = "true" ]; then \
		echo "Creating COLCON_IGNORE in $(VENV_DIR) to avoid colcon processing..."; \
		touch $(VENV_DIR)/COLCON_IGNORE; \
		echo "Running ROS 2 VS Code configurator..."; \
		chmod +x configure.sh; \
		./configure.sh; \
		echo ""; \
	fi
	@echo "To activate the Python environment, run:"
	@echo "    . $(VENV_DIR)/bin/activate"

clean:
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_DIR)