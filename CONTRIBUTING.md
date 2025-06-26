# Contributing to DeepMimic

Thank you for your interest in contributing to DeepMimic! This document provides guidelines for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- Be respectful and inclusive
- Use welcoming and constructive language
- Focus on what is best for the community
- Show empathy towards other community members

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

1. **System Information**:
   - OS version (e.g., Ubuntu 22.04)
   - Python version
   - TensorFlow version
   - GPU/CUDA version (if applicable)

2. **Clear Description**:
   - What you expected to happen
   - What actually happened
   - Steps to reproduce the issue

3. **Code and Logs**:
   - Minimal code example
   - Error messages and stack traces
   - Relevant log files

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- Clear description of the enhancement
- Use cases and motivation
- Possible implementation approach
- Impact on existing functionality

### Pull Requests

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/DeepMimic.git
   cd DeepMimic
   ```

2. **Set Up Development Environment**:
   ```bash
   ./setup.sh
   source setup_env.sh
   pip install -r requirements-dev.txt
   ```

3. **Create Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make Changes**:
   - Follow the coding style (see below)
   - Add tests for new functionality
   - Update documentation as needed

5. **Test Your Changes**:
   ```bash
   # Run basic tests
   python -c "import DeepMimicCore; print('Core import OK')"
   
   # Run specific functionality tests
   python DeepMimic.py --arg_file args/run_humanoid3d_walk_args.txt --test_episodes 1
   
   # Run code quality checks
   black --check .
   flake8 .
   ```

6. **Commit and Push**:
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   git push origin feature/your-feature-name
   ```

7. **Create Pull Request**:
   - Use a clear and descriptive title
   - Reference related issues
   - Describe changes and motivation
   - Include screenshots/videos for visual changes

## Coding Style

### Python Code

We follow PEP 8 with some modifications:

- **Line Length**: 88 characters (Black formatter)
- **Imports**: Use `isort` for import sorting
- **Type Hints**: Encouraged for new code
- **Docstrings**: Use Google-style docstrings

Example:
```python
import numpy as np
from typing import List, Optional

def train_policy(
    motion_file: str,
    num_iterations: int,
    learning_rate: float = 0.001
) -> Optional[str]:
    """Train a character control policy.
    
    Args:
        motion_file: Path to motion capture file
        num_iterations: Number of training iterations
        learning_rate: Learning rate for optimization
        
    Returns:
        Path to saved model file, or None if training failed
        
    Raises:
        ValueError: If motion_file doesn't exist
    """
    # Implementation here
    pass
```

### C++ Code

For C++ code in `DeepMimicCore/`:

- **Style**: Follow Google C++ Style Guide
- **Naming**: Use camelCase for variables, PascalCase for classes
- **Comments**: Extensive comments for physics/RL algorithms
- **Memory**: Use smart pointers where appropriate

### Documentation

- **README**: Keep main README concise but comprehensive
- **Code Comments**: Explain "why" not just "what"
- **API Documentation**: Document all public functions/classes
- **Examples**: Provide working examples for new features

## Development Workflow

### Setting Up Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/DeepMimic.git
cd DeepMimic

# Add upstream remote
git remote add upstream https://github.com/xbpeng/DeepMimic.git

# Install in development mode
./setup.sh
source setup_env.sh

# Install development dependencies
pip install black flake8 isort mypy pytest pytest-cov
```

### Testing

```bash
# Quick smoke test
python -c "import DeepMimicCore; print('✅ Core import successful')"

# Test basic functionality
python DeepMimic.py --help

# Test MPI functionality
mpiexec -n 2 python -c "from mpi4py import MPI; print(f'Rank {MPI.COMM_WORLD.Get_rank()}')"

# Run a short training test
mpiexec -n 2 python DeepMimic_Optimizer.py \
    --arg_file args/train_humanoid3d_walk_args.txt \
    --max_iter 100
```

### Code Quality Checks

```bash
# Format code
black .
isort .

# Check style
flake8 .

# Type checking (optional)
mypy learning/ --ignore-missing-imports
```

### Common Development Tasks

#### Adding a New Character

1. Create character definition file in `data/characters/`
2. Add corresponding argument files in `args/`
3. Update documentation
4. Add tests

#### Adding a New Motion Skill

1. Add motion file to `data/motions/`
2. Create training argument file
3. Create evaluation argument file
4. Test training convergence
5. Document the new skill

#### Modifying Learning Algorithms

1. Update relevant files in `learning/`
2. Ensure TensorFlow 2.x compatibility
3. Test with existing argument files
4. Update documentation
5. Consider backward compatibility

## Project Structure

```
DeepMimic/
├── args/                    # Configuration files
├── data/                    # Character models and motions
├── DeepMimicCore/          # C++ physics simulation
├── learning/               # RL algorithms and networks
├── util/                   # Utility scripts
├── output/                 # Training outputs
├── docs/                   # Documentation
├── tests/                  # Test files
├── .github/                # CI/CD workflows
├── setup.sh               # Installation script
├── setup_env.sh           # Environment activation
├── requirements.txt       # Python dependencies
└── README.md              # Main documentation
```

## Release Process

For maintainers:

1. **Version Bumping**: Update version in relevant files
2. **Changelog**: Update CHANGELOG.md with new features/fixes
3. **Testing**: Run full test suite on multiple platforms
4. **Tagging**: Create git tag with semantic versioning
5. **Release Notes**: Create GitHub release with notes

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search existing issues and discussions
3. Create a new issue with the "question" label
4. Join community discussions

Thank you for contributing to DeepMimic! 🚀
