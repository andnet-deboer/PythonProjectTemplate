.PHONY: setup clean

# Default Python venv directory
VENV_DIR := venv

# Extract extras from Make goals, skipping 'setup'
EXTRAS := $(filter-out setup,$(MAKECMDGOALS))

setup:
	@echo "Bootstrapping Python environment..."
	@chmod +x setup_env.sh
	@if [ -n "$(EXTRAS)" ]; then \
		bash setup_env.sh $(VENV_DIR) $(EXTRAS); \
	else \
		bash setup_env.sh $(VENV_DIR); \
	fi
	@echo "To activate, run:"
	@echo "   . $(VENV_DIR)/bin/activate"
clean:
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_DIR)