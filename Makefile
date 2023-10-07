.PHONY: clean clean-test clean-docs clean-pyc clean-build docs help
.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

ifeq (, $(shell which snakeviz))
	PROFILE = pytest --profile-svg
	PROFILE_RESULT = prof/combined.svg
	PROFILE_VIEWER = $(BROWSER)
else
    PROFILE = pytest --profile
    PROFILE_RESULT = prof/combined.prof
	PROFILE_VIEWER = snakeviz
endif

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

lock: ## Generate a new poetry.lock file (To be done after adding new requirements to pyproject.toml)
	poetry lock

install-poetry: ## Install poetry package
	pip install poetry==1.6.0

install: clean ## Install all package and development dependencies for testing to the active Python's site-packages
	poetry install --all-extras --with=testing,linting,docs

install-all: install-poetry install ## Install poetry along with all package and development dependencies

clean: clean-build clean-pyc clean-test clean-docs ## Remove all build, test, coverage and Python artifacts

clean-build: ## Remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -path ./.venv -prune -false -o -name '*.egg-info' -exec rm -fr {} +
	find . -path ./.venv -prune -false -o -name '*.egg' -exec rm -f {} +

clean-pyc: ## Remove Python file artifacts
	find . -path ./.venv -prune -false -o -name '*.pyc' -exec rm -f {} +
	find . -path ./.venv -prune -false -o -name '*.pyo' -exec rm -f {} +
	find . -path ./.venv -prune -false -o -name '*~' -exec rm -f {} +
	find . -path ./.venv -prune -false -o -name '__pycache__' -exec rm -fr {} +

clean-test: ## Remove test and coverage artifacts
	rm -f .coverage
	rm -f coverage.xml
	rm -fr htmlcov/
	rm -fr .pytest_cache
	rm -fr .mypy_cache
	rm -fr prof/

clean-docs: ## Remove docs artifacts
	rm -fr docs/_build
	rm -fr docs/api

format: ## Format code with docformatter, isort and black
	docformatter doors tests --in-place
	isort doors tests
	black doors tests

lint: ## Check style with flake8 and pylint
	flake8 doors tests
	pylint doors tests

typing: ## Check static typing with mypy
	mypy doors

pre-commit-checks: ## Run pre-commit checks on all files
	pre-commit run --hook-stage manual --all-files

lint-all: pre-commit-checks lint typing ## Run all linting checks.

test: ## Run tests quickly with the default Python
	pytest

test-docs: docs-api ## Check docs using doc8
	pydocstyle doors
	doc8 docs
	$(MAKE) -C docs doctest

coverage: ## Check code coverage quickly with the default Python
	coverage run --source doors -m pytest
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html

profile:  ## Create a profile from test cases
	$(PROFILE) $(TARGET)
	$(PROFILE_VIEWER) $(PROFILE_RESULT)

docs-api:  ## Generate the API documentation for Sphinx
	rm -rf docs/api
	sphinx-apidoc -e -M -o docs/api doors

docs: docs-api ## Generate Sphinx HTML documentation, including API docs
	$(MAKE) -C docs clean
	$(MAKE) -C docs html
	$(MAKE) open-docs

.SILENT:
open-docs: ## Open the generated Sphinx HTML documentation
	@if [ "$$port" != "" ]; then\
		python3 -m http.server --directory docs/_build/html/ "$$port";\
	else\
		echo "No port was specified as a make argument. Trying a local run...";\
		$(BROWSER) docs/_build/html/index.html;\
	fi

servedocs: docs ## Compile the docs watching for changes
	watchmedo shell-command -p '*.rst' -c '$(MAKE) -C docs html' -R -D .
