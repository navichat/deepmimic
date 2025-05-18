# DeepMimic Modification & Research Options

## Project Purpose & Capabilities
DeepMimic is a physics-based character animation and reinforcement learning environment. It enables training of simulated agents (e.g., humanoids, quadrupeds) to imitate reference motions (from mocap data) using deep RL. The current minimal version supports:
- Training agents to match a single reference motion (imitation learning)
- Running and visualizing pre-trained policies
- Parallelized training using MPI

## Ultimate Goal: Interactive 3D Chat Avatar

**Vision:**
- A 3D humanoid avatar that can move around a 3D space, converse with the user, and express emotions through body and facial animation.
- The avatar can follow user instructions (e.g., "walk to the door", "wave hello"), generate and synchronize speech with animation, and display clear emotional states.
- (Optional) Multiple avatars can interact in the same environment.

**Note:**
- **Audio and facial animation synchronization is currently handled by NVIDIA Audio2Face.**
- Integrating everything into a single model is a long-term goal, but using modular solutions (e.g., separate body and face animation systems) is acceptable and practical for now.
- Steps related to audio and facial animation are marked as optional and can be revisited as technology and project needs evolve.

---

## Progressive Implementation Plan (Expanded)

### **Stage 1: Reference Motion Imitation (Animation Matching)**
- [ ] **Review and understand the current imitation reward:**
  - Locate the reward function in `DeepMimicCore/` (C++), likely in a file/class related to the environment or agent.
  - Identify which terms are used for imitation (e.g., pose, velocity, end-effector, root).
- [ ] **Train a policy to imitate a single reference motion:**
  - Use an existing arg file (e.g., `args/run_humanoid3d_spinkick_args.txt`).
  - Run training and monitor logs in `output/`.
- [ ] **Visualize and log the agent's ability to match the reference motion:**
  - Use `DeepMimic.py` to visualize.
  - Check logs for reward breakdown and convergence.
- [ ] **Tune imitation reward and ensure stable training:**
  - Adjust reward weights in the arg file.
  - Document any changes that improve stability or performance.

### **Stage 2: Add Simple Goal Conditioning**
- [ ] **Add a static goal position to the environment:**
  - Add `--goal_pos x y z` to an arg file.
  - Parse this argument in `env/deepmimic_env.py` and store as `self.goal_pos`.
- [ ] **Augment the agent's observation/state vector:**
  - In `env/deepmimic_env.py`, find the function that builds the observation (e.g., `GetState` or similar).
  - Append the goal position (or relative vector to goal) to the observation.
  - Update the C++ state vector if needed (via SWIG interface).
- [ ] **Add a reward term for goal-reaching:**
  - In the C++ reward function, add a term: `-alpha * distance_to_goal`.
  - Make `alpha` configurable via the arg file.
- [ ] **Train a policy to both imitate and reach the goal:**
  - Use the updated arg file.
  - Monitor both imitation and goal-reaching performance.
- [ ] **Tune reward weights and test with different goals:**
  - Try different values for `alpha` and different goal positions.
  - Log and visualize the agent's ability to reach the goal while imitating.

### **Stage 3: Dynamic/Interactive Goals**
- [ ] **Allow the goal position to change during an episode:**
  - Add a method in `env/deepmimic_env.py` to update `self.goal_pos` at runtime.
  - Expose this method via a Python API or socket/HTTP server.
- [ ] **Test agent's ability to adapt to moving/changing goals:**
  - Write a script to send new goals during an episode.
  - Log how quickly and accurately the agent adapts.

### **Stage 4: Multi-Skill or Multi-Goal Tasks**
- [ ] **Enable loading multiple reference motions:**
  - Update the environment to accept a list of motions in the arg file.
  - Add logic to select or blend between motions based on a skill/task indicator.
- [ ] **Add a skill/task indicator to the observation:**
  - Extend the observation vector with a one-hot or continuous skill indicator.
- [ ] **Train the agent for skill selection/blending:**
  - Use curriculum learning: start with two skills, then add more.
  - Evaluate transitions and skill selection accuracy.

### **Stage 5: Emotion/Expression Conditioning (Optional)**
- [ ] **Add an emotion/style input to the policy:**
  - Extend the observation vector with an emotion indicator.
  - Update the arg file and training loop to support emotion conditioning.
- [ ] **Train or fine-tune for different emotions/styles:**
  - Use different reference motions or reward shaping for each emotion.
- [ ] **Integrate with external facial animation (optional):**
  - Pass emotion state to Audio2Face or similar system.

### **Stage 6: Conversational Integration & Command Following**
- [ ] **Connect to a conversational AI backend:**
  - Implement a WebSocket or REST API server in Python.
  - Parse user commands and map them to navigation goals or skill/emotion triggers.
- [ ] **Log and visualize avatar responses:**
  - Record all commands and avatar actions.
  - Visualize in the simulation window or via logs.

### **Stage 7: Multi-Agent/Scene Support (Optional)**
- [ ] **Extend the environment for multiple agents:**
  - Update the environment and state vector to support multiple agents.
  - Implement agent-agent interaction logic (e.g., collision, communication).
- [ ] **Test and visualize group behaviors:**
  - Run scenarios with multiple avatars and log interactions.

---

## Policy Design for Goal-Directed, Expressive Avatars

### 1. Policy Input (Observation) Design
- **Agent state:** Joint positions, velocities, root position/orientation, etc.
- **Reference motion state:** Current/next frame of the reference motion.
- **Goal information:** Position (and possibly orientation) of the navigation target, relative to the agent.
- **Emotion/intent signal:** Vector or one-hot encoding for desired emotion or style.
- **(Optional) Conversation context:** High-level intent or summary of last user utterance.

**Example observation vector:**
```
[agent_state, reference_motion_state, goal_relative_pos, emotion_vector, ...]
```

### 2. Policy Output (Action) Design
- **Joint torques or target positions:** As in standard DeepMimic.
- **(Optional) Skill selector:** For multi-skill or hierarchical policies.

### 3. Policy Architecture Options
- **Monolithic policy:** One network for all inputs/outputs.
- **Hierarchical/conditional policy:** High-level controller selects skill/emotion, low-level controller executes.
- **Motion-conditioned policy:** Policy is conditioned on reference motion and goal, can blend/transition between motions.

### 4. Reward Design
- **Imitation reward:** Match the reference motion.
- **Goal reward:** Negative distance to goal, or bonus for reaching the goal.
- **Emotion/expression reward:** (If feasible) reward for matching target emotion/style.
- **Task success reward:** Bonus for completing user-specified tasks (e.g., reaching a location, waving).

### 5. Training Regime
- **Curriculum learning:** Start with simple tasks, increase complexity.
- **Multi-task learning:** Train on a variety of goals, emotions, and skills in parallel.
- **Imitation + RL:** Combine imitation loss and RL reward.

### 6. Practical Considerations
- **Data:** Reference motions for all desired skills/emotions.
- **Conditioning:** Ensure policy can generalize to new goals/emotions.
- **Evaluation:** Test both imitation quality and task success.

**Recommendation:**
- Start with a motion-conditioned policy: Input = [agent state, reference motion, goal, emotion].
- Use curriculum learning: navigation + imitation, then add emotion/skill conditioning.
- Keep emotion/facial animation modular for now (e.g., Audio2Face for face, DeepMimic for body).
- Plan for hierarchical/conditional control if scaling to many skills/complex behaviors.

---

## Environment Awareness and Obstacle Detection

For robust navigation, multi-skill generalization, and interactive behaviors, the avatar must be able to perceive and react to obstacles and the environment. This requires providing the policy with appropriate sensory inputs about the surroundings. Possible input modalities include:

- **Raycasts**: Simulate distance sensors by casting rays from the agent to detect nearby obstacles (similar to lidar or depth sensors).
- **Depth maps**: Provide a 2D array representing distances to the nearest surfaces in the agent's field of view.
- **Occupancy grids**: A coarse grid indicating which regions of space are occupied or free.
- **Lidar-like sensors**: Simulate 1D or 2D scans of the environment.
- **Direct access to environment state**: For research, the agent may be given privileged information about object positions, terrain, or obstacles.

**Implementation Notes:**
- These inputs should be appended to the agent's observation/state vector, alongside agent state, reference motion, goal, and emotion indicators.
- The observation construction logic in `env/deepmimic_env.py` (and corresponding C++ code) should be updated to include these sensory inputs.
- The policy architecture may need to be adjusted (e.g., with convolutional layers for depth maps or occupancy grids).
- Reward functions can be shaped to encourage safe navigation and obstacle avoidance.

**References:**
- See Stage 2 and Stage 4 of the roadmap for where to augment the observation vector.
- For more details, consult the 'Policy Design' section above.

---

## Desired Extensions: Complex Behaviors
The original DeepMimic/AMP papers and demos show more advanced behaviors, such as:
- **Goal-directed navigation**: The agent not only imitates a motion, but also navigates to a target point in space.
- **Targeted actions**: The agent must hit, kick, or interact with a specific object or target.
- **Multi-goal or multi-skill tasks**: The agent switches between different reference motions or skills based on a higher-level goal.
- **AMP-style adversarial priors**: Using adversarial learning to encourage more natural or stylized behaviors.

## Implementation Steps: Navigation & Command Following

### Step 1: Add Goal Specification to Arg Files and Environment
- [ ] **Edit an arg file** (e.g., `args/cust_humanoid3d.txt`) to add a new argument:
  ```
  --goal_pos 5.0 0.0 2.0
  ```
- [ ] **Update arg parsing in Python** (`env/deepmimic_env.py`):
  - Locate where arguments are parsed.
  - Add logic to read `--goal_pos` and store as `self.goal_pos`.
- [ ] **Propagate goal to C++** (if needed):
  - Ensure the goal is passed from Python to C++ (via SWIG or environment reset).

### Step 2: Augment the Observation/State Vector
- [ ] **Identify state vector construction**:
  - In `env/deepmimic_env.py`, find the function that constructs the agent's observation/state (e.g., `get_state`, `get_obs`).
  - In `DeepMimicCore/`, look for the state vector definition.
- [ ] **Add goal information**:
  - Append the goal position (or relative vector from agent to goal) to the observation.
  - Ensure this is included in both Python and C++.

### Step 3: Modify the Reward Function
- [ ] **Locate reward calculation**:
  - In C++ (`DeepMimicCore/`), find the reward function (e.g., `CalcReward`, `GetReward`).
  - In Python, check for any reward shaping post-C++.
- [ ] **Add goal reward**:
  - Add a term to the reward function that penalizes distance to the goal, e.g.:
    ```cpp
    double dist = (agent_pos - goal_pos).norm();
    reward -= alpha * dist;
    ```
  - Make `alpha` tunable via the arg file if desired.

### Step 4: Expose a Command API
- [ ] **Prototype a simple API**:
  - In `env/deepmimic_env.py`, add a function to set the goal position at runtime (e.g., `set_goal_pos(x, y, z)`).
  - Optionally, use a simple socket or HTTP server to receive commands from an external process.
- [ ] **Test with manual commands**:
  - Write a small script to send new goal positions to the environment and verify the agent updates its target.

### Step 5: Logging and Visualization
- [ ] **Log navigation events**:
  - Add print/log statements in Python and C++ to record when the goal changes and the agent's distance to the goal.
- [ ] **Visualize the goal**:
  - If possible, render the goal position in the simulation window (e.g., as a marker or object).

## Refined Implementation Plans & To-Do Integration

### 1. Navigation & Command Following
**Objective:** Enable the avatar to move to arbitrary points in a 3D environment on command.

**Steps:**
- [ ] Implement goal-conditioned navigation (see previous plan).
- [ ] Expose a Python API or socket interface to receive navigation commands from a chat system or UI.
- [ ] Add pathfinding or obstacle avoidance if needed.
- [ ] Log and visualize navigation commands and agent responses.

### 2. Conversational Integration
**Objective:** Connect the avatar to a conversational AI backend (e.g., LLM, Rasa, Dialogflow).

**Steps:**
- [ ] Set up a communication channel (WebSocket, REST API, etc.) between the RL environment and the chat backend.
- [ ] Parse user commands (e.g., "walk to the door", "wave hello") and translate them into environment goals or skill triggers.
- [ ] Send avatar state and events back to the chat system for context-aware responses.
- [ ] Prototype with simple text commands, then expand.

### 3. Audio-Animation Synchronization (Optional/External)
**Objective:** Synchronize mouth and facial movements with generated speech.

**Current Approach:**
- This is currently handled by NVIDIA Audio2Face, which provides high-quality facial animation from audio.
- Integration with DeepMimic is modular: body animation is handled by DeepMimic, facial animation by Audio2Face.

**Long-Term Goal:**
- Integrate facial and body animation into a single model if feasible.
- For now, maintain modularity and focus on robust body control and navigation.

**Steps (Optional):**
- [ ] Integrate a TTS (text-to-speech) engine that outputs both audio and phoneme/timing data.
- [ ] Implement a viseme/mouth-shape animation system in the avatar (C++/Python or via a 3D engine).
- [ ] Trigger facial/mouth animations in sync with the audio stream.
- [ ] Test with sample utterances and refine timing.

### 4. Emotion & Expression Control
**Objective:** Allow the avatar to express emotions (happy, sad, angry, etc.) through body and face.

**Steps:**
- [ ] Expand the agent's action space or skill set to include expressive/emotional motions.
- [ ] Add an "emotion" input to the policy (e.g., one-hot or continuous vector).
- [ ] Train or fine-tune policies for each emotion, or use style transfer/adversarial methods (AMP).
- [ ] Allow the chat system to set the avatar's emotion based on conversation context.
- [ ] Log and visualize emotion state and transitions.

### 5. Multi-Agent/Scene Support (Optional)
**Objective:** Support multiple avatars and interactions in the same environment.

**Steps:**
- [ ] Extend the environment to handle multiple agents, each with their own state, goals, and conversation context.
- [ ] Implement agent-agent interaction logic (e.g., turn-taking, group behaviors).
- [ ] Log and visualize multi-agent interactions.

---

## Expanded To-Do List
- [ ] Identify where in the codebase the observation/state vector is defined and can be extended (Python and C++).
- [ ] Locate reward function(s) and how to add new terms (Python and C++).
- [ ] Find how reference motions are loaded and if multiple can be used (Python and C++).
- [ ] Investigate how to add new environment objects (targets, obstacles) (C++ and Python exposure).
- [ ] Explore how to expose new arguments in arg files and propagate them to the environment/agent.
- [ ] Review AMP/adversarial code (if present) and how to enable/extend it.
- [ ] Add/extend logging for new features and debugging.
- [ ] Add/extend UI controls for interactive testing.
- [ ] Document all new features and changes for future users/contributors.
- [ ] Prototype and test navigation command API.
- [ ] Integrate a simple chat backend and test command parsing.
- [ ] Research and integrate TTS/viseme systems for audio-animation sync.
- [ ] Design and implement emotion/expressiveness pipeline.
- [ ] Plan and test multi-agent scenarios if needed.

---

**This document is a living record. Add new ideas, findings, and modification plans as you explore and extend DeepMimic.** 