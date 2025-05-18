# DeepMimic User Manual

## Running Training

To run training with the correct environment for local dependencies, use the following command from the project root:

```bash
env LD_LIBRARY_PATH="$PWD/libs/glew-2.1.0/lib:$PWD/libs/freeglut-3.0.0/install/lib:$PWD/libs/bullet3-2.88/install/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    mpiexec --oversubscribe -n <NUM_WORKERS> python3 DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_spinkick_args.txt --num_workers <NUM_WORKERS>
```

Replace `<NUM_WORKERS>` with the number of parallel workers you want to use (e.g., 2, 4, 8, etc.).

**Example:**
```bash
env LD_LIBRARY_PATH="$PWD/libs/glew-2.1.0/lib:$PWD/libs/freeglut-3.0.0/install/lib:$PWD/libs/bullet3-2.88/install/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    mpiexec --oversubscribe -n 2 python3 DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_spinkick_args.txt --num_workers 2
```

This ensures all required local libraries are found by each MPI worker. 