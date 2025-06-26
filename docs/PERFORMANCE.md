# DeepMimic Performance Guide

This guide provides tips and best practices for optimizing DeepMimic training and inference performance.

## 🚀 Training Performance

### Hardware Recommendations

#### CPU
- **Minimum**: 8 cores, 16GB RAM
- **Recommended**: 16+ cores, 32GB+ RAM
- **Optimal**: High-performance CPU with good single-thread performance

#### GPU (Optional)
- **Training**: NVIDIA GPU with 8GB+ VRAM
- **Inference**: Any modern GPU for visualization acceleration
- **CUDA**: Version 11.0+ recommended

#### Storage
- **SSD recommended** for faster data loading
- **NVMe SSD optimal** for high I/O workloads

### MPI Configuration

#### Number of Workers
```bash
# Start with CPU core count
NUM_CORES=$(nproc)
mpiexec -n $NUM_CORES python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Scale based on memory usage
# Rule of thumb: 2-4GB RAM per worker
WORKERS=$(($(free -g | awk '/^Mem:/{print $2}') / 3))
mpiexec -n $WORKERS python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
```

#### MPI Tuning
```bash
# Use process binding for better performance
mpiexec --bind-to core -n 16 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Adjust network settings for multi-node
export OMPI_MCA_btl_tcp_if_include=eth0
export OMPI_MCA_oob_tcp_if_include=eth0
```

### Training Parameters

#### Batch Size Optimization
```txt
# In your argument file
--mini_batch_size 32    # Default
--mini_batch_size 64    # Increase for better GPU utilization
--mini_batch_size 16    # Decrease if running out of memory
```

#### Learning Rate Scheduling
```txt
# Adaptive learning rate
--learning_rate 0.001
--lr_decay 0.99
--lr_decay_interval 10000
```

#### Memory Management
```txt
# Reduce memory usage
--replay_buffer_size 50000    # Reduce from default 100000
--max_samples 1000000         # Limit total samples
```

### Monitoring Performance

#### Training Speed
```bash
# Monitor training progress
tail -f output/log.txt | grep "Iter\|FPS\|Time"

# Calculate samples per second
python -c "
import re
with open('output/log.txt', 'r') as f:
    lines = f.readlines()
    for line in lines[-10:]:
        if 'Iter' in line and 'Time' in line:
            print(line.strip())
"
```

#### System Resources
```bash
# Monitor CPU and memory
htop

# Monitor GPU usage (if available)
nvidia-smi -l 1

# Monitor I/O usage
iotop
```

#### Memory Profiling
```bash
# Profile memory usage
python -m memory_profiler DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Monitor per-process memory
ps aux | grep python | grep DeepMimic
```

## ⚡ Optimization Strategies

### Code-Level Optimizations

#### TensorFlow Settings
```python
# In your training script
import os
os.environ['TF_USE_LEGACY_KERAS'] = '1'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Reduce TF logging

import tensorflow as tf
# Configure GPU memory growth
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    for gpu in gpus:
        tf.config.experimental.set_memory_growth(gpu, True)
```

#### Environment Variables
```bash
# Set in setup_env.sh or before training
export OMP_NUM_THREADS=4              # Control OpenMP threads
export MKL_NUM_THREADS=4              # Control MKL threads  
export NUMEXPR_NUM_THREADS=4          # Control NumExpr threads
export OPENBLAS_NUM_THREADS=4         # Control OpenBLAS threads
export TF_ENABLE_ONEDNN_OPTS=1        # Enable OneDNN optimizations
```

### Training Tricks

#### Curriculum Learning
```txt
# Start with simpler motions, gradually increase complexity
--motion_file data/motions/humanoid3d_walk.txt     # Start simple
# Later switch to:
--motion_file data/motions/humanoid3d_spinkick.txt # More complex
```

#### Warm Starting
```txt
# Start from pre-trained model
--model_file output/previous_model.ckpt
--init_model output/previous_model.ckpt
```

#### Adaptive Sampling
```txt
# Adjust episode length based on performance
--episode_max_length 1000    # Shorter episodes initially
--episode_max_length 2000    # Increase as training progresses
```

## 🔧 System Optimization

### Linux Kernel Tuning
```bash
# Increase shared memory limits
echo 'kernel.shmmax = 68719476736' | sudo tee -a /etc/sysctl.conf
echo 'kernel.shmall = 4294967296' | sudo tee -a /etc/sysctl.conf

# Optimize network buffers for MPI
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

### Process Prioritization
```bash
# Run training with higher priority
nice -n -10 mpiexec -n 16 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Use ionice for I/O priority
ionice -c 1 -n 0 mpiexec -n 16 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
```

### Storage Optimization
```bash
# Use tmpfs for temporary files (if enough RAM)
sudo mount -t tmpfs -o size=8G tmpfs /tmp/deepmimic_temp
export TMPDIR=/tmp/deepmimic_temp

# Use separate disk for output
mkdir /fast_storage/deepmimic_output
ln -sf /fast_storage/deepmimic_output output
```

## 📊 Benchmarking

### Performance Baselines

#### Training Speed (Samples/Second)
- **Single Core**: ~100-200 samples/sec
- **8 Workers**: ~800-1600 samples/sec  
- **16 Workers**: ~1500-3000 samples/sec
- **32 Workers**: ~2500-5000 samples/sec (diminishing returns)

#### Memory Usage (Per Worker)
- **Humanoid Skills**: 1-3GB RAM
- **Dog Locomotion**: 0.5-2GB RAM
- **Complex Motions**: 2-4GB RAM

#### Training Time (to Convergence)
- **Simple Locomotion**: 4-8 hours (16 workers)
- **Acrobatic Skills**: 8-16 hours (16 workers)
- **Complex Sequences**: 12-24 hours (16 workers)

### Benchmarking Script
```bash
#!/bin/bash
# benchmark.sh - Simple performance benchmark

echo "DeepMimic Performance Benchmark"
echo "================================"

# System info
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null || echo 'None')"

# Test import speed
echo "Testing import speed..."
time python -c "import DeepMimicCore"

# Test MPI scaling
for workers in 1 2 4 8 16; do
    echo "Testing with $workers workers..."
    timeout 60 mpiexec -n $workers python DeepMimic_Optimizer.py \
        --arg_file args/train_humanoid3d_walk_args.txt \
        --max_iter 100 \
        2>&1 | grep "FPS\|samples/sec" | tail -1
done
```

## 🐛 Performance Debugging

### Common Performance Issues

#### Slow Training
```bash
# Check if I/O bound
iotop -o  # Look for high I/O wait

# Check if CPU bound
htop  # Look for high CPU usage across cores

# Check if memory bound
free -h  # Look for low available memory
```

#### Memory Leaks
```bash
# Monitor memory over time
while true; do
    ps aux | grep DeepMimic | awk '{sum+=$6} END {print "Total Memory:", sum/1024, "MB"}'
    sleep 10
done
```

#### MPI Bottlenecks
```bash
# Profile MPI communication
mpiexec -n 16 python -m cProfile -o profile.out DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Analyze profile
python -c "
import pstats
p = pstats.Stats('profile.out')
p.sort_stats('cumulative').print_stats(20)
"
```

### Profiling Tools

#### Python Profiling
```bash
# Line-by-line profiling
kernprof -l -v DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# Memory profiling
mprof run --python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
mprof plot
```

#### System Profiling
```bash
# CPU profiling with perf
perf record -g mpiexec -n 16 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
perf report

# Memory profiling with valgrind
valgrind --tool=massif python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt
```

## 🎯 Production Deployment

### Cluster Deployment
```bash
# Multi-node MPI training
mpiexec -n 64 -hostfile hosts python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt

# SLURM integration
sbatch --nodes=4 --ntasks-per-node=16 --time=24:00:00 train_job.sh
```

### Cloud Optimization
```bash
# AWS EC2 recommendations
# Instance type: c5.4xlarge or c5.9xlarge for CPU-intensive
# Instance type: p3.2xlarge for GPU acceleration

# Google Cloud recommendations  
# Instance type: c2-standard-16 or c2-standard-30
# Instance type: n1-standard-16 with GPU for acceleration
```

For specific performance questions or issues, please create an issue with your system specifications and performance measurements.
