# DeepMimic Project Structure

This document provides an overview of the DeepMimic project structure and organization.

## 📁 Root Directory

```
DeepMimic/
├── 📄 README.md                    # Main documentation
├── 📄 LICENSE                      # MIT License
├── 📄 CHANGELOG.md                 # Version history and changes  
├── 📄 CONTRIBUTING.md              # Contributing guidelines
├── 📄 requirements.txt             # Python dependencies
├── 📄 requirements-dev.txt         # Development dependencies
├── 🔧 setup.sh                     # Main installation script
├── 🔧 setup_env.sh                 # Environment activation script
├── 🔧 verify_installation.sh       # Installation verification
├── 🐍 DeepMimic.py                 # Main visualization/evaluation script
├── 🐍 DeepMimic_Optimizer.py       # Training optimizer (modern)
├── 🐍 mpi_run.py                   # Legacy MPI training runner
├── 🐍 bvh_convert.py               # BVH to DeepMimic motion converter
└── 📁 [various directories]/       # See detailed breakdown below
```

## 📚 Documentation (`docs/`)

```
docs/
├── 📄 API.md                       # API reference documentation
├── 📄 PERFORMANCE.md               # Performance optimization guide
├── 📊 training_guide.md            # Detailed training instructions
├── 🎭 character_creation.md        # Custom character creation guide
├── 🎮 motion_format.md             # Motion file format specification
└── 🔧 troubleshooting.md           # Common issues and solutions
```

## ⚙️ Configuration (`args/`)

Training and evaluation argument files:

```
args/
├── 🏃 Humanoid Training:
│   ├── train_humanoid3d_walk_args.txt
│   ├── train_humanoid3d_run_args.txt
│   ├── train_humanoid3d_backflip_args.txt
│   ├── train_humanoid3d_spinkick_args.txt
│   └── [other skills]...
├── 🏃 Humanoid Evaluation:
│   ├── run_humanoid3d_walk_args.txt
│   ├── run_humanoid3d_run_args.txt
│   ├── run_humanoid3d_backflip_args.txt
│   └── [other skills]...
├── 🐕 Dog Training:
│   ├── train_dog3d_pace_args.txt
│   ├── train_dog3d_trot_args.txt
│   ├── train_dog3d_canter_args.txt
│   └── train_dog3d_spin_args.txt
├── 🐕 Dog Evaluation:
│   ├── run_dog3d_pace_args.txt
│   ├── run_dog3d_trot_args.txt
│   └── [other gaits]...
├── 🎭 AMP (Adversarial Motion Priors):
│   ├── train_amp_humanoid3d_locomotion_args.txt
│   ├── train_amp_target_humanoid3d_locomotion_args.txt
│   ├── run_amp_humanoid3d_locomotion_args.txt
│   └── [other AMP variants]...
└── 📽️ Motion Playback:
    ├── play_motion_humanoid3d_args.txt
    └── play_motion_dog_args.txt
```

## 🎭 Data (`data/`)

```
data/
├── 📁 characters/                  # Character model definitions
│   ├── humanoid3d.txt             # Main humanoid character
│   ├── dog.txt                    # Quadruped dog character
│   └── [custom characters]/
├── 📁 controllers/                 # Control parameter files
│   ├── humanoid3d_ctrl.txt        # Humanoid controller config
│   └── dog_ctrl.txt               # Dog controller config
├── 📁 motions/                     # Motion capture data
│   ├── humanoid3d_walk.txt        # Walking motion
│   ├── humanoid3d_run.txt         # Running motion
│   ├── humanoid3d_backflip.txt    # Acrobatic motions
│   ├── dog_pace.txt               # Dog locomotion
│   └── [hundreds of motion files]/
├── 📁 policies/                    # Pre-trained models and networks
│   ├── humanoid/
│   │   ├── models/                # Saved model checkpoints
│   │   └── nets/                  # Network architecture definitions
│   └── dog/
│       ├── models/
│       └── nets/
└── 📁 scenes/                      # Environment configurations
    ├── imitate_humanoid3d.txt
    └── imitate_dog.txt
```

## 🧠 Learning Algorithms (`learning/`)

```
learning/
├── 🔄 Core RL Framework:
│   ├── rl_world.py                # Main RL environment interface
│   ├── agent.py                   # Base agent class
│   ├── tf_agent.py               # TensorFlow agent base
│   └── experience.py             # Experience replay utilities
├── 🤖 Agent Implementations:
│   ├── ppo_agent.py              # Proximal Policy Optimization
│   ├── amp_agent.py              # Adversarial Motion Priors
│   ├── pg_agent.py               # Policy Gradient base
│   └── [other agents]/
├── 🧮 Neural Networks:
│   ├── nets/
│   │   ├── fc_2layers_1024units.py
│   │   ├── fc_2layers_gated_1024units.py
│   │   └── [other architectures]/
│   └── net_util.py               # Network utilities
├── 🔧 TensorFlow Utilities:
│   ├── tf_util.py                # TF helper functions
│   ├── tf_normalizer.py          # Input normalization
│   ├── tf_distribution_gaussian_diag.py  # Policy distributions
│   └── tf_logger.py              # TensorFlow logging
├── 🔀 Distributed Training:
│   ├── solvers/
│   │   ├── mpi_solver.py         # MPI-based distributed solver
│   │   └── solver.py             # Base solver class
│   └── mpi_util.py               # MPI utilities
└── 📊 Training Utilities:
    ├── normalizer.py             # State normalization
    ├── replay_buffer.py          # Experience replay
    └── util.py                   # General utilities
```

## 🏗️ Core Engine (`DeepMimicCore/`)

C++ physics simulation and Python bindings:

```
DeepMimicCore/
├── 🔧 Build System:
│   ├── Makefile                   # Linux build configuration
│   ├── CMakeLists.txt            # CMake configuration
│   └── DeepMimicCore.sln         # Visual Studio solution (Windows)
├── 🐍 Python Interface:
│   ├── DeepMimicCore.i           # SWIG interface file
│   ├── DeepMimicCore_wrap.cxx    # Generated SWIG wrapper
│   └── DeepMimicCore.py          # Generated Python module
├── 🎮 Main Classes:
│   ├── Main.cpp                  # Entry point
│   ├── World.cpp/h               # Simulation world
│   ├── Character.cpp/h           # Character simulation
│   ├── Motion.cpp/h              # Motion playback
│   └── Controller.cpp/h          # Character control
├── 🏃 Character Components:
│   ├── KinCharacter.cpp/h        # Kinematic character
│   ├── SimCharacter.cpp/h        # Simulated character
│   ├── BipedController.cpp/h     # Biped control
│   └── QuadrupedController.cpp/h # Quadruped control
├── 🎯 RL Integration:
│   ├── RLScene.cpp/h             # RL environment interface
│   ├── RLSceneImitate.cpp/h      # Imitation learning scene
│   └── TerrainRLCharController.cpp/h  # Terrain navigation
├── 🔧 Utilities:
│   ├── ArgParser.cpp/h           # Argument parsing
│   ├── JsonUtil.cpp/h            # JSON utilities
│   ├── MathUtil.cpp/h            # Math utilities
│   └── FileUtil.cpp/h            # File I/O utilities
└── 📁 External Dependencies:
    ├── bullet/                   # Bullet Physics (if included)
    ├── eigen/                    # Eigen math library (if included)
    └── [other dependencies]/
```

## 🛠️ Utilities (`util/`)

```
util/
├── 📊 Data Processing:
│   ├── motion_util.py            # Motion data utilities
│   ├── arg_parser.py             # Argument file parsing
│   └── json_util.py              # JSON utilities
├── 🎥 Visualization:
│   ├── plot_training.py          # Training curve plotting
│   └── render_util.py            # Rendering utilities
├── 🔄 Data Conversion:
│   ├── bvh_parser.py             # BVH file parsing
│   └── motion_converter.py       # Motion format conversion
└── 🧪 Testing:
    ├── test_runner.py            # Test execution
    └── benchmark.py              # Performance benchmarks
```

## 📦 External Libraries (`libs/`)

Built and installed external dependencies:

```
libs/
├── 📁 bullet/                     # Bullet Physics build
│   ├── include/                  # Header files
│   ├── lib/                      # Compiled libraries
│   └── build/                    # Build files
├── 📁 eigen/                      # Eigen math library
├── 📁 freeglut/                   # OpenGL utility toolkit
├── 📁 glew/                       # OpenGL extension wrangler
└── 📁 swig/                       # SWIG wrapper generator
```

## 🐍 Python Environment (`py/` or virtual environment)

```
py/  # or deepmimic_env/
├── 📁 bin/                        # Executables (python, pip, etc.)
├── 📁 lib/                        # Python libraries
│   └── python3.x/
│       └── site-packages/        # Installed packages
├── 📁 include/                    # Python headers
└── 📁 share/                      # Shared data
```

## 📤 Outputs (`output/`)

Training and evaluation outputs:

```
output/
├── 📊 Training Logs:
│   ├── log.txt                   # Main training log
│   ├── train_log.txt             # Detailed metrics
│   └── progress.txt              # Progress summary
├── 🧠 Model Files:
│   ├── model.ckpt                # Latest model checkpoint
│   ├── model.ckpt.meta           # TensorFlow metadata
│   ├── int_model.ckpt            # Intermediate checkpoints
│   └── [timestamped models]/
├── 📈 Visualizations:
│   ├── training_curves.png       # Loss/reward plots
│   └── performance_metrics.png   # Performance analysis
└── 🎥 Recorded Videos:
    ├── evaluation_episodes/      # Episode recordings
    └── training_progress/        # Training visualization
```

## 🔧 CI/CD (`.github/`)

```
.github/
├── 📁 workflows/                  # GitHub Actions
│   ├── build-and-test.yml       # Main CI/CD pipeline
│   ├── release.yml               # Release automation
│   └── security-scan.yml        # Security scanning
├── 📁 ISSUE_TEMPLATE/            # Issue templates
└── 📄 pull_request_template.md   # PR template
```

## 🗂️ Additional Files

```
📁 Root Level:
├── 🔍 .gitignore                 # Git ignore patterns
├── 🔍 .gitattributes             # Git attributes
├── 📋 .pre-commit-config.yaml    # Pre-commit hooks
├── 🐳 Dockerfile                 # Docker container definition
├── 📝 .editorconfig              # Editor configuration
└── 🔧 pyproject.toml             # Python project configuration
```

## 📂 Directory Usage Guidelines

### **Read-Only Directories**
- `data/`: Reference data, modify carefully
- `DeepMimicCore/`: Only modify for core engine changes
- `.github/`: CI/CD configuration

### **Generated/Temporary Directories**  
- `output/`: Training outputs, safe to clean
- `libs/`: Built libraries, regenerated by setup
- `__pycache__/`: Python cache, safe to delete

### **Configuration Directories**
- `args/`: Modify for different experiments
- `docs/`: Update documentation as needed

### **Development Directories**
- `learning/`: Core algorithm development
- `util/`: Utility function development

## 🔍 Finding Specific Components

### **Want to modify training algorithms?**
→ `learning/` directory

### **Need to add a new character?**
→ `data/characters/` + `data/controllers/`

### **Want to create new motions?**
→ `data/motions/` + motion conversion tools

### **Need to change network architecture?**
→ `learning/nets/` + `data/policies/`

### **Want to modify physics simulation?**
→ `DeepMimicCore/` (requires C++ knowledge)

### **Need training configuration?**
→ `args/` directory

### **Looking for documentation?**
→ `docs/` directory + `README.md`

This structure supports both research experimentation and production deployment while maintaining clear separation of concerns.
