# DeepMimic API Reference

This document provides a comprehensive API reference for the DeepMimic framework.

## 🏗️ Core Architecture

### DeepMimicCore (C++ Extension)

The core simulation engine built with Bullet Physics.

#### Classes

##### `cWorld`
Main simulation world containing characters and environment.

```cpp
class cWorld {
public:
    void Init();
    void Reset();
    void Update(double time_step);
    void Draw();
    
    // Character management
    void AddCharacter(std::shared_ptr<cCharacter> character);
    void RemoveCharacter(int char_id);
    std::shared_ptr<cCharacter> GetCharacter(int char_id);
    
    // Physics properties
    void SetGravity(const tVector& gravity);
    tVector GetGravity() const;
};
```

##### `cCharacter`
Represents a simulated character (humanoid, dog, etc.).

```cpp
class cCharacter {
public:
    // Pose and motion
    void SetPose(const Eigen::VectorXd& pose);
    Eigen::VectorXd GetPose() const;
    void SetVel(const Eigen::VectorXd& vel);
    Eigen::VectorXd GetVel() const;
    
    // Root transformation
    tVector GetRootPos() const;
    void SetRootPos(const tVector& pos);
    tQuaternion GetRootRot() const;
    void SetRootRot(const tQuaternion& rot);
    
    // Joint control
    void ApplyControlForces(const Eigen::VectorXd& forces);
    Eigen::VectorXd CalcJointTorques(const Eigen::VectorXd& pose) const;
    
    // Physical properties
    double GetMass() const;
    tVector GetCOM() const;
    tVector GetCOMVel() const;
};
```

##### `cMotion`
Handles motion capture data and playback.

```cpp
class cMotion {
public:
    bool LoadMotion(const std::string& filename);
    void CalcFrame(double time, Eigen::VectorXd& out_frame) const;
    double GetDuration() const;
    int GetNumFrames() const;
    bool IsLoop() const;
    
    // Frame interpolation
    void CalcFramePhase(double phase, Eigen::VectorXd& out_frame) const;
    int CalcCycleCount(double time) const;
};
```

### Python API

#### Core Modules

##### `learning.rl_world.RLWorld`
High-level interface for reinforcement learning environments.

```python
class RLWorld:
    def __init__(self, args):
        """Initialize RL world with configuration."""
        
    def reset(self) -> np.ndarray:
        """Reset environment and return initial observation."""
        
    def step(self, action: np.ndarray) -> Tuple[np.ndarray, float, bool, dict]:
        """Take a step in the environment.
        
        Args:
            action: Action vector
            
        Returns:
            observation: Next state observation
            reward: Reward for this step
            done: Whether episode is complete
            info: Additional information
        """
        
    def get_action_space(self) -> gym.Space:
        """Get action space specification."""
        
    def get_observation_space(self) -> gym.Space:
        """Get observation space specification."""
        
    def render(self, mode: str = 'human') -> Optional[np.ndarray]:
        """Render the environment."""
```

##### `learning.tf_agent.TFAgent`
Base class for TensorFlow-based agents.

```python
class TFAgent:
    def __init__(self, world, id, json_data):
        """Initialize agent with world and configuration."""
        
    def reset(self):
        """Reset agent state."""
        
    def update(self, samples):
        """Update agent with training samples."""
        
    def eval(self, record_flags=None):
        """Evaluate agent performance."""
        
    def save_model(self, out_path: str):
        """Save model to file."""
        
    def load_model(self, in_path: str):
        """Load model from file."""
        
    def get_output_path(self) -> str:
        """Get output directory path."""
        
    def get_int_output_path(self) -> str:
        """Get intermediate output path."""
```

##### `learning.ppo_agent.PPOAgent`
Proximal Policy Optimization agent implementation.

```python
class PPOAgent(TFAgent):
    def __init__(self, world, id, json_data):
        """Initialize PPO agent."""
        
    def _build_nets(self, json_data):
        """Build actor and critic networks."""
        
    def _train_step(self):
        """Perform one training step."""
        
    def _update_policy(self, adv_samples, val_samples):
        """Update policy with advantage samples."""
        
    def _update_critic(self, val_samples):
        """Update critic with value samples."""
```

##### `learning.amp_agent.AMPAgent`
Adversarial Motion Priors agent implementation.

```python
class AMPAgent(PPOAgent):
    def __init__(self, world, id, json_data):
        """Initialize AMP agent."""
        
    def _build_discriminator(self, json_data):
        """Build discriminator network."""
        
    def _train_discriminator(self, exp_samples, policy_samples):
        """Train discriminator to distinguish real vs generated motion."""
        
    def _calc_amp_rewards(self, samples):
        """Calculate AMP-based style rewards."""
```

#### Utility Functions

##### `util.arg_parser`
Command-line argument parsing utilities.

```python
def parse_args(arg_file: Optional[str] = None) -> argparse.Namespace:
    """Parse command-line arguments from file or command line.
    
    Args:
        arg_file: Path to argument file
        
    Returns:
        Parsed arguments namespace
    """

def load_args(arg_file: str) -> List[str]:
    """Load arguments from file.
    
    Args:
        arg_file: Path to argument file
        
    Returns:
        List of argument strings
    """
```

##### `util.motion_util`
Motion capture data utilities.

```python
def load_motion(motion_file: str) -> dict:
    """Load motion from JSON file.
    
    Args:
        motion_file: Path to motion file
        
    Returns:
        Motion data dictionary
    """

def calc_motion_length(motion_data: dict) -> float:
    """Calculate total motion duration.
    
    Args:
        motion_data: Motion data dictionary
        
    Returns:
        Duration in seconds
    """

def interpolate_frame(motion_data: dict, time: float) -> np.ndarray:
    """Interpolate motion frame at given time.
    
    Args:
        motion_data: Motion data dictionary
        time: Time in seconds
        
    Returns:
        Interpolated frame data
    """
```

## 🎮 Configuration API

### Argument Files

Argument files use a simple key-value format:

```txt
# Training configuration
--scene HumanoidImitate
--motion_file data/motions/humanoid3d_walk.txt
--char_ctrl_file data/controllers/humanoid3d_ctrl.txt

# Training parameters
--num_workers 16
--max_iter 100000000
--int_output_iters 100
--int_save_iters 500

# Network architecture
--actor_net_file data/policies/humanoid/nets/actor_net.prototxt
--critic_net_file data/policies/humanoid/nets/critic_net.prototxt

# Learning parameters
--learning_rate 0.001
--discount 0.95
--mini_batch_size 32
```

### JSON Configuration

Character and network definitions use JSON format:

#### Character Configuration
```json
{
    "CharType": "BipedSymm3D",
    "CharFile": "data/characters/humanoid3d.txt",
    "StateParams": {
        "IncludeCharState": true,
        "IncludeGoalState": false
    },
    "ActionParams": {
        "ActionType": "Continuous",
        "ActionSpace": "Torque"
    }
}
```

#### Network Configuration
```json
{
    "NetworkType": "FC",
    "Layers": [
        {
            "Type": "FC",
            "OutputSize": 1024,
            "Activation": "ReLU",
            "WeightInit": "Xavier"
        },
        {
            "Type": "FC", 
            "OutputSize": 512,
            "Activation": "ReLU"
        },
        {
            "Type": "FC",
            "OutputSize": "ActionSize",
            "Activation": "Linear"
        }
    ]
}
```

## 🔧 Extension Points

### Creating Custom Agents

```python
from learning.tf_agent import TFAgent
import tensorflow.compat.v1 as tf

class CustomAgent(TFAgent):
    def __init__(self, world, id, json_data):
        super().__init__(world, id, json_data)
        self._build_custom_nets(json_data)
        
    def _build_custom_nets(self, json_data):
        """Build custom network architecture."""
        with self._tf_sess.graph.as_default():
            with tf.variable_scope(self.get_name()):
                # Define custom networks
                pass
                
    def _train_step(self):
        """Custom training step implementation."""
        # Your training logic here
        pass
```

### Creating Custom Environments

```python
from learning.rl_world import RLWorld

class CustomWorld(RLWorld):
    def __init__(self, args):
        super().__init__(args)
        
    def _calc_reward(self, agent_id):
        """Calculate custom reward function."""
        # Your reward calculation
        return reward
        
    def _calc_done(self, agent_id):
        """Calculate custom termination condition."""
        # Your termination logic
        return done
```

### Adding New Character Types

1. **Define Character Model**: Create character definition file
2. **Implement Controller**: Add controller configuration
3. **Update Argument Files**: Create training/evaluation configs
4. **Test Integration**: Verify with existing training pipeline

## 📊 Monitoring and Logging

### Training Metrics

```python
# Available metrics during training
metrics = {
    'iteration': int,           # Current iteration
    'samples': int,             # Total samples collected
    'reward_mean': float,       # Average reward
    'reward_std': float,        # Reward standard deviation
    'episode_length': float,    # Average episode length
    'learning_rate': float,     # Current learning rate
    'policy_loss': float,       # Policy loss
    'critic_loss': float,       # Critic loss
    'entropy': float,           # Policy entropy
    'kl_divergence': float,     # KL divergence
    'grad_norm': float,         # Gradient norm
}
```

### Custom Logging

```python
import logging

# Set up custom logger
logger = logging.getLogger('deepmimic')
logger.setLevel(logging.INFO)

# Add custom metrics
def log_custom_metrics(agent, metrics):
    """Log custom training metrics."""
    logger.info(f"Custom metric: {metrics}")
    
    # Write to TensorBoard (if available)
    if hasattr(agent, '_summary_writer'):
        with agent._summary_writer.as_default():
            tf.summary.scalar('custom_metric', metrics['value'], step=metrics['step'])
```

## 🧪 Testing API

### Unit Testing

```python
import unittest
from learning.ppo_agent import PPOAgent

class TestPPOAgent(unittest.TestCase):
    def setUp(self):
        """Set up test environment."""
        self.args = load_test_args()
        self.world = create_test_world(self.args)
        self.agent = PPOAgent(self.world, 0, {})
        
    def test_agent_initialization(self):
        """Test agent initialization."""
        self.assertIsNotNone(self.agent)
        
    def test_training_step(self):
        """Test training step execution."""
        initial_loss = self.agent.get_loss()
        self.agent._train_step()
        # Assert training progresses
        
if __name__ == '__main__':
    unittest.main()
```

### Integration Testing

```python
def test_end_to_end_training():
    """Test complete training pipeline."""
    args = parse_args('args/test_training_args.txt')
    world = RLWorld(args)
    agent = create_agent(world, args)
    
    # Run short training
    for i in range(10):
        agent.update()
        
    # Verify training progress
    assert agent.get_total_samples() > 0
```

## 🔍 Debugging API

### Debug Utilities

```python
def debug_agent_state(agent):
    """Print agent state for debugging."""
    print(f"Agent ID: {agent.get_id()}")
    print(f"Total samples: {agent.get_total_samples()}")
    print(f"Current loss: {agent.get_loss()}")
    
def debug_world_state(world):
    """Print world state for debugging."""
    for i in range(world.get_num_agents()):
        agent = world.get_agent(i)
        print(f"Agent {i} reward: {agent.get_avg_reward()}")
```

For detailed implementation examples, see the source code in the `learning/` directory.
