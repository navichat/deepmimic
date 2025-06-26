# DeepMimic: Physics-Based Character Animation with Deep Reinforcement Learning

[![Build and Test](https://github.com/xbpeng/DeepMimic/workflows/DeepMimic%20Build%20and%20Test/badge.svg)](https://github.com/xbpeng/DeepMimic/actions)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![TensorFlow 2.x](https://img.shields.io/badge/TensorFlow-2.x-orange.svg)](https://tensorflow.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> **Modern Implementation**: This repository has been updated for compatibility with modern systems, including TensorFlow 2.x, Python 3.8+, and improved CI/CD workflows.

## 📖 Introduction

DeepMimic is a deep reinforcement learning framework for training physics-based character controllers to imitate motion capture data. This codebase accompanies the following research papers:

**"DeepMimic: Example-Guided Deep Reinforcement Learning of Physics-Based Character Skills"**  
[Project Page](https://xbpeng.github.io/projects/DeepMimic/index.html) | [Paper](https://dl.acm.org/doi/10.1145/3197517.3201311)
![DeepMimic Skills](images/deepmimic_teaser.png)

**"AMP: Adversarial Motion Priors for Stylized Physics-Based Character Control"**  
[Project Page](https://xbpeng.github.io/projects/AMP/index.html) | [Paper](https://dl.acm.org/doi/10.1145/3450626.3459670)
![AMP Skills](images/amp_teaser.png)

## ✨ Features

- 🤖 **Multi-character Support**: Train humanoid and quadruped characters
- 🎯 **Motion Imitation**: Learn from motion capture data
- 🏃‍♂️ **Diverse Skills**: Locomotion, acrobatics, fighting, and more
- 🌐 **Distributed Training**: MPI-based parallel training
- 🎮 **Interactive Visualization**: Real-time 3D rendering and control
- 🔧 **Modern Compatibility**: TensorFlow 2.x, Python 3.8+, Ubuntu 22.04+

## 🚀 Quick Start

### Automated Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/xbpeng/DeepMimic.git
cd DeepMimic

# Run the automated setup script
chmod +x setup.sh
./setup.sh

# Activate the environment
source setup_env.sh

# Test the installation
python DeepMimic.py --arg_file args/run_humanoid3d_spinkick_args.txt
```

### Docker Setup (Alternative)

```bash
# Build Docker image
docker build -t deepmimic .

# Run container
docker run -it --rm -v $(pwd):/workspace deepmimic
```

## 📋 System Requirements

### Operating System
- **Ubuntu 20.04+** (recommended)
- **Ubuntu 18.04+** (supported)
- **Other Linux distributions** (may require manual dependency installation)

### Hardware
- **CPU**: Multi-core processor (8+ cores recommended for training)
- **Memory**: 8GB RAM minimum, 16GB+ recommended
- **GPU**: NVIDIA GPU with CUDA support (optional, for faster training)
- **Graphics**: OpenGL 3.2+ compatible graphics card

### Software Dependencies
- **Python**: 3.8, 3.9, 3.10, or 3.11
- **TensorFlow**: 2.x (automatically installed)
- **MPI**: OpenMPI or MPICH (for distributed training)
- **OpenGL**: 3.2+
- **Build Tools**: cmake, make, clang/gcc


## 🏗️ Installation

### Automatic Installation (Recommended)

The provided setup script handles all dependencies and compilation automatically:

```bash
# Install system dependencies and build the project
./setup.sh

# Activate the Python environment
source setup_env.sh

# Verify installation
python -c "import DeepMimicCore; print('✅ Installation successful!')"
```

### Manual Installation

If you prefer manual installation or encounter issues with the automatic setup:

#### 1. System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    python3 python3-pip python3-venv \
    libgl1-mesa-dev libx11-dev libxrandr-dev libxi-dev \
    libopenmpi-dev mesa-utils clang cmake bison byacc \
    build-essential wget curl tar autoconf libtool \
    pkg-config libssl-dev zlib1g-dev libglew-dev \
    freeglut3-dev libglu1-mesa-dev libffi-dev \
    patchelf swig
```

**Fedora/RHEL:**
```bash
sudo dnf install -y \
    python3 python3-pip python3-virtualenv \
    mesa-libGL-devel libX11-devel libXrandr-devel libXi-devel \
    openmpi-devel mesa-utils clang cmake bison byacc \
    gcc-c++ wget curl tar autoconf libtool \
    pkgconfig openssl-devel zlib-devel glew-devel \
    freeglut-devel mesa-libGLU-devel libffi-devel \
    patchelf swig
```

#### 2. Python Environment

```bash
# Create virtual environment
python3 -m venv deepmimic_env
source deepmimic_env/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

#### 3. Build Core Libraries

```bash
# Build the C++ extension
cd DeepMimicCore
make clean
make python
cd ..
```

#### 4. Verify Installation

```bash
python -c "import DeepMimicCore; print('✅ Core library built successfully')"
python DeepMimic.py --help
```

### 🐳 Docker Installation

For a containerized environment:

```dockerfile
# Use the provided Dockerfile
docker build -t deepmimic .
docker run -it --rm \
    -v $(pwd):/workspace \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    deepmimic
```

## 📚 Usage Guide

### Running Pre-trained Models

View pre-trained character skills:

```bash
# Humanoid skills
python DeepMimic.py --arg_file args/run_humanoid3d_spinkick_args.txt
python DeepMimic.py --arg_file args/run_humanoid3d_backflip_args.txt
python DeepMimic.py --arg_file args/run_humanoid3d_walk_args.txt

# Dog locomotion
python DeepMimic.py --arg_file args/run_dog3d_pace_args.txt
python DeepMimic.py --arg_file args/run_dog3d_trot_args.txt

# AMP (Adversarial Motion Priors)
python DeepMimic.py --arg_file args/run_amp_target_humanoid3d_locomotion_args.txt
```

### Playing Motion Capture Data

View raw motion capture clips:

```bash
python DeepMimic.py --arg_file args/play_motion_humanoid3d_args.txt
```

### Training New Policies

Train character controllers using distributed learning:

```bash
# Train humanoid skills (recommended: 8-16 workers)
mpiexec -n 16 python DeepMimic_Optimizer.py \
    --arg_file args/train_humanoid3d_spinkick_args.txt

# Train dog locomotion
mpiexec -n 8 python DeepMimic_Optimizer.py \
    --arg_file args/train_dog3d_pace_args.txt

# Train with AMP
mpiexec -n 16 python DeepMimic_Optimizer.py \
    --arg_file args/train_amp_target_humanoid3d_locomotion_args.txt
```

### Alternative Training Method

Using the legacy MPI runner:

```bash
python mpi_run.py --arg_file args/train_humanoid3d_spinkick_args.txt --num_workers 16
```

### 🎮 Interactive Controls

When running the visualizer:

- **Camera**: Right-click + drag to pan, scroll to zoom
- **Forces**: Left-click + drag to apply forces to character
- **Reset**: Press `R` to reset the episode
- **Reload**: Press `L` to reload configuration
- **Pause**: Press `Space` to pause/resume
- **Step**: Press `>` to step frame-by-frame
- **Debug**: Press `X` to spawn random objects


## 🎭 Motion Capture Data

### Using Existing Motions

Motion files are located in `data/motions/` and use JSON format. To play a motion:

```bash
# Edit the motion file path in the args file
vim args/play_motion_humanoid3d_args.txt
# Set: --motion_file data/motions/your_motion.txt

# Play the motion
python DeepMimic.py --arg_file args/play_motion_humanoid3d_args.txt
```

### Motion File Format

Each motion file contains keyframes with the following structure:

```json
{
  "Loop": "wrap",  // "wrap" for cyclic, "none" for acyclic
  "Frames": [
    [
      0.0333,           // Frame duration (seconds)
      0, 0.85, 0,       // Root position (x, y, z)
      1, 0, 0, 0,       // Root rotation (w, x, y, z quaternion)
      // ... joint rotations
    ]
  ]
}
```

**Frame Format** (197 values total):
- Duration: 1 value
- Root position: 3 values (x, y, z in meters)
- Root rotation: 4 values (quaternion w, x, y, z)
- Joint rotations: 189 values (quaternions for 3D joints, scalars for 1D joints)

### Creating Custom Motions

1. **Convert from BVH**: Use the `bvh_convert.py` utility
2. **Manual Creation**: Follow the JSON format specification
3. **Motion Editing**: Modify existing motions in `data/motions/`

## 🔧 Configuration

### Training Parameters

Key parameters in training argument files:

```txt
--num_workers 16              # Number of MPI processes
--int_output_iters 100        # Output interval
--int_save_iters 500          # Save interval
--max_iter 100000000          # Maximum iterations
--learning_rate 0.001         # Learning rate
--discount 0.95               # Discount factor
--mini_batch_size 32          # Batch size
```

### Environment Settings

```txt
--scene                       # Scene type (humanoid, dog, etc.)
--motion_file                 # Reference motion file
--model_file                  # Pre-trained model (for evaluation)
--output_path                 # Training output directory
```

### Character Customization

- **Humanoid**: Modify `data/characters/humanoid3d.txt`
- **Dog**: Modify `data/characters/dog.txt`
- **Custom Characters**: Create new character definition files

## 📊 Monitoring Training

### Output Files

Training produces several output files in the `output/` directory:

```
output/
├── log.txt                   # Training logs
├── model.ckpt                # Latest model checkpoint
├── int_model.ckpt           # Intermediate checkpoints
└── train_log.txt            # Detailed training metrics
```

### Training Progress

Monitor training with:

```bash
# Watch training progress
tail -f output/log.txt

# Plot training curves
python util/plot_training.py output/train_log.txt
```

### Expected Performance

- **Training Time**: 8-24 hours for most skills (16 workers)
- **Sample Efficiency**: 20-100 million samples
- **Memory Usage**: 2-8GB per worker process
- **Convergence**: Usually within 50-80% of maximum iterations

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Import/Library Errors

**Problem**: `ImportError: libGLEW.so.2.1: cannot open shared object file`
```bash
# Solution 1: Install GLEW
sudo apt-get install libglew-dev

# Solution 2: Create symbolic links
sudo ln -sf /usr/lib/x86_64-linux-gnu/libGLEW.so.2.1 /usr/lib/libGLEW.so.2.1
```

**Problem**: `ImportError: libBulletDynamics.so.2.88: cannot open shared object file`
```bash
# Solution: Set library path
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# Add to ~/.bashrc for persistence
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
```

**Problem**: `ImportError: No module named 'DeepMimicCore'`
```bash
# Solution: Rebuild the core library
cd DeepMimicCore
make clean
make python
cd ..
```

#### 2. TensorFlow Issues

**Problem**: TensorFlow 2.x compatibility errors
```bash
# Solution: Environment already configured for TF 2.x
source setup_env.sh  # This sets TF_USE_LEGACY_KERAS=1
```

**Problem**: `AttributeError: module 'tensorflow' has no attribute 'contrib'`
```bash
# Solution: The codebase has been updated to use tf.compat.v1
# If you still see this error, ensure you're using the updated files
```

#### 3. MPI Issues

**Problem**: MPI processes not starting or failing silently
```bash
# Check MPI installation
mpiexec --version

# Test with simple command
mpiexec -n 2 python -c "from mpi4py import MPI; print(f'Rank {MPI.COMM_WORLD.Get_rank()}')"

# Use alternative MPI launcher
mpirun -n 16 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
```

**Problem**: MPI hanging or deadlocking
```bash
# Reduce number of workers
mpiexec -n 4 python DeepMimic_Optimizer.py --arg_file your_args.txt

# Check system resources
htop  # Monitor CPU and memory usage
```

#### 4. Graphics/Display Issues

**Problem**: OpenGL errors or black screen
```bash
# Check OpenGL support
glxinfo | grep "OpenGL version"

# For headless systems, use Xvfb
xvfb-run -a python DeepMimic.py --arg_file args/run_humanoid3d_walk_args.txt
```

**Problem**: Display issues with SSH
```bash
# Enable X11 forwarding
ssh -X username@hostname

# Or use VNC for better performance
```

#### 5. Performance Issues

**Problem**: Slow training or high memory usage
```bash
# Monitor resources
htop
nvidia-smi  # If using GPU

# Reduce batch size or number of workers
# Edit training args file:
--mini_batch_size 16  # Reduce from 32
--num_workers 8       # Reduce from 16
```

**Problem**: Training not converging
```bash
# Check learning rate and other hyperparameters
# Try different reference motions
# Ensure motion file matches character model
```

### 🐛 Debugging Tips

1. **Verbose Logging**: Add `--verbose` flag to argument files
2. **Single Process**: Test with `mpiexec -n 1` first
3. **Environment Check**: Run diagnostic script:

```bash
python -c "
import sys
print('Python version:', sys.version)
import tensorflow as tf
print('TensorFlow version:', tf.__version__)
import DeepMimicCore
print('DeepMimicCore imported successfully')
from mpi4py import MPI
print('MPI processes:', MPI.COMM_WORLD.Get_size())
"
```

4. **Log Analysis**: Check output logs for errors:
```bash
grep -i error output/log.txt
grep -i warning output/log.txt
```

### 📞 Getting Help

If you encounter issues not covered here:

1. **Check Issues**: Search [GitHub Issues](https://github.com/xbpeng/DeepMimic/issues)
2. **Create Issue**: Provide system info, error messages, and steps to reproduce
3. **Community**: Join discussions in the repository
4. **Documentation**: Check the original papers for algorithm details

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup

```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Check code style
black --check .
flake8 .
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Citation

If you use this code in your research, please cite:

```bibtex
@article{peng2018deepmimic,
  title={DeepMimic: Example-guided deep reinforcement learning of physics-based character skills},
  author={Peng, Xue Bin and Abbeel, Pieter and Levine, Sergey and van de Panne, Michiel},
  journal={ACM Transactions on Graphics (TOG)},
  volume={37},
  number={4},
  pages={1--14},
  year={2018},
  publisher={ACM}
}

@article{peng2021amp,
  title={AMP: Adversarial motion priors for stylized physics-based character control},
  author={Peng, Xue Bin and Ma, Ze and Abbeel, Pieter and Levine, Sergey and Kanazawa, Angjoo},
  journal={ACM Transactions on Graphics (TOG)},
  volume={40},
  number={4},
  pages={1--15},
  year={2021},
  publisher={ACM}
}
```

## 🙏 Acknowledgements

- **Original Authors**: Xue Bin Peng, Pieter Abbeel, Sergey Levine, Michiel van de Panne, Ze Ma, Angjoo Kanazawa
- **Physics Engine**: [Bullet Physics](https://github.com/bulletphysics/bullet3)
- **Machine Learning**: [TensorFlow](https://tensorflow.org/)
- **Community**: All contributors and users providing feedback

## 🔗 Related Projects

- **AMP**: [Adversarial Motion Priors](https://github.com/xbpeng/DeepMimic)
- **CALM**: [Composable Action-Conditional Locomotion](https://github.com/nv-tlabs/CALM)
- **ASE**: [Adversarial Skill Embeddings](https://github.com/nv-tlabs/ASE)
- **URDF Conversion**: [ROS-compatible humanoid](https://github.com/EricVoll/amp_motion_conversion)

---

**Made with ❤️ by the DeepMimic community**

