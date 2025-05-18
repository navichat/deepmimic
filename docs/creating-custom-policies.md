# Creating Custom Policies in DeepMimic

This guide explains how DeepMimic's training setup works and how to create a custom policy, using the example of a target-locomotion agent that performs a specific motion (e.g., a dance or punch) when it reaches the target.

---

## 1. Overview: How DeepMimic Training Works

- **Arg files** (e.g., `args/train_amp_target_humanoid3d_locomotion_args.txt`) specify the environment, agent, motions, and training parameters.
- **Agent config files** (e.g., `data/agents/ct_agent_humanoid_amp_tasks.txt`) define the neural network, learning rates, and AMP-specific settings.
- **Motion files** (e.g., `data/motions/humanoid3d_walk.txt`) or **motion datasets** (e.g., `data/datasets/humanoid3d_clips_locomotion.txt`) provide the reference motions for imitation.
- **C++ scene/environment code** (e.g., `DeepMimicCore/scenes/SceneTargetAMP.cpp`) implements the reward, goal logic, and episode flow.
- **Python environment wrappers** (e.g., `env/deepmimic_env.py`) interface with the C++ core and expose the RL API.

---

## 2. Custom Policy Example: "Do a Motion at the Target"

Suppose you want an agent to navigate to a target, then perform a specific motion (e.g., a punch or dance) upon arrival.

### Step 1: Prepare Your Motions
- Collect the locomotion and target-action motions you want to use (e.g., `humanoid3d_walk.txt`, `humanoid3d_punch.txt`).
- Create a **motion dataset** (JSON) that lists both types, e.g.:
  ```json
  {
    "Motions": [
      {"Weight": 3, "File": "data/motions/humanoid3d_walk.txt"},
      {"Weight": 1, "File": "data/motions/humanoid3d_punch.txt"}
    ]
  }
  ```
- Save as `data/datasets/humanoid3d_clips_walk_punch.txt` (see existing datasets for format).

### Step 2: Update the Arg File
- Copy and modify an existing training arg file (e.g., `train_amp_target_humanoid3d_locomotion_args.txt`).
- Set `--motion_file` to your new dataset:
  ```
  --motion_file data/datasets/humanoid3d_clips_walk_punch.txt
  ```
- Adjust other parameters as needed (target distance, reward weights, etc).

### Step 3: Modify the Environment Logic (C++)
- Open `DeepMimicCore/scenes/SceneTargetAMP.cpp`.
- The function `bool cSceneTargetAMP::CheckTargetSucc() const` determines if the agent has reached the target.
- To trigger a new motion at the target:
  - Add logic to switch the reference motion when `CheckTargetSucc()` returns true.
  - You may need to add a state variable (e.g., `mAtTarget`) and logic to select the "target action" motion.
  - Optionally, add a skill/task indicator to the observation vector so the policy knows which phase it's in (locomotion vs. action).
- Update the reward function (`CalcReward`) to encourage successful completion of the target action.

### Step 4: (Optional) Extend the Observation Vector
- In C++ (`RecordState` or `RecordGoal` in `SceneTargetAMP.cpp`), append a flag or indicator (e.g., `at_target`) to the state/goal vector.
- In Python, ensure the observation size matches and is passed to the policy.

### Step 5: Update the Agent Config (if needed)
- If using a skill/task indicator, update the agent config (e.g., `ct_agent_humanoid_amp_tasks.txt`) to reflect the new observation size.
- You may also want to tune learning rates or network size for multi-skill tasks.

### Step 6: Train the Policy
- Run training with your new arg file:
  ```bash
  python DeepMimic_Optimizer.py --arg_file args/train_amp_target_humanoid3d_walk_punch_args.txt
  ```
- Monitor logs in `output/` for reward breakdown and convergence.

### Step 7: Run and Visualize
- Create a run arg file pointing to your trained model and dataset.
- Run with:
  ```bash
  python DeepMimic.py --arg_file args/run_amp_target_humanoid3d_walk_punch_args.txt
  ```

---

## 3. Key Files and Code Locations

- **Arg files:** `args/train_*.txt`, `args/run_*.txt`
- **Agent configs:** `data/agents/ct_agent_*.txt`
- **Motion datasets:** `data/datasets/*.txt`
- **Motions:** `data/motions/*.txt`
- **C++ scene logic:** `DeepMimicCore/scenes/SceneTargetAMP.cpp`, `SceneTargetAMP.h`
- **Python env wrapper:** `env/deepmimic_env.py`

---

## 4. Tips for Custom Behaviors
- Use motion datasets to combine multiple skills.
- Add a skill/task indicator to the observation for phase-based behaviors.
- Modify the reward to encourage both navigation and the target action.
- Use curriculum learning: start with navigation, then add the target action.
- Document your changes for reproducibility.

---

## 5. References
- See `docs/modification-options.md` for a broader roadmap and advanced ideas.
- Look at existing multi-skill datasets (e.g., `humanoid3d_clips_walk_punch.txt`) for format inspiration.
- Review C++ scene code for reward and episode logic. 