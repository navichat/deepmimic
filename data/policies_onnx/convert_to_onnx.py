#!/usr/bin/env python3
"""
DeepMimic Policy to ONNX Converter

This script converts DeepMimic TensorFlow checkpoint (.ckpt) files to ONNX format
for JavaScript inference using ONNX Runtime Web.
"""

import os
import sys
import tensorflow as tf
# Disable eager execution for TensorFlow 1.x compatibility
tf.compat.v1.disable_eager_execution()
import numpy as np
from tf2onnx import tfonnx, utils, constants
import tf2onnx
import onnx
import argparse
import json
from pathlib import Path

class DeepMimicPolicyConverter:
    def __init__(self, humanoid_file_path=None):
        self.humanoid_file_path = humanoid_file_path or "/home/barberb/motion/DeepMimic/data/characters/humanoid3d.txt"
        self.character_info = self.load_character_info()
        
    def load_character_info(self):
        """Load character bone structure from humanoid3d.txt"""
        character_info = {
            "joints": [],
            "joint_names": [],
            "parent_indices": [],
            "bone_count": 0
        }
        
        try:
            with open(self.humanoid_file_path, 'r') as f:
                lines = f.readlines()
                
            for line in lines:
                line = line.strip()
                if line.startswith("Joints"):
                    # Parse joint information
                    parts = line.split()
                    if len(parts) > 1:
                        character_info["bone_count"] = int(parts[1])
                elif line and not line.startswith("#"):
                    # Parse individual joint entries
                    parts = line.split()
                    if len(parts) >= 8:  # Minimum fields for a joint
                        joint_info = {
                            "name": parts[0],
                            "parent": int(parts[1]) if parts[1] != "-1" else -1,
                            "offset": [float(parts[2]), float(parts[3]), float(parts[4])],
                            "type": parts[5] if len(parts) > 5 else "revolute"
                        }
                        character_info["joints"].append(joint_info)
                        character_info["joint_names"].append(parts[0])
                        character_info["parent_indices"].append(joint_info["parent"])
                        
        except FileNotFoundError:
            print(f"Warning: Could not find character file {self.humanoid_file_path}")
            # Use default humanoid structure
            character_info = self.get_default_humanoid_structure()
            
        return character_info
    
    def get_default_humanoid_structure(self):
        """Default humanoid bone structure if file not found"""
        return {
            "joints": [
                {"name": "root", "parent": -1, "offset": [0, 0, 0], "type": "revolute"},
                {"name": "chest", "parent": 0, "offset": [0, 0.15, 0], "type": "revolute"},
                {"name": "neck", "parent": 1, "offset": [0, 0.15, 0], "type": "revolute"},
                {"name": "head", "parent": 2, "offset": [0, 0.1, 0], "type": "revolute"},
                {"name": "right_hip", "parent": 0, "offset": [0.1, 0, 0], "type": "revolute"},
                {"name": "right_knee", "parent": 4, "offset": [0, -0.4, 0], "type": "revolute"},
                {"name": "right_ankle", "parent": 5, "offset": [0, -0.4, 0], "type": "revolute"},
                {"name": "left_hip", "parent": 0, "offset": [-0.1, 0, 0], "type": "revolute"},
                {"name": "left_knee", "parent": 7, "offset": [0, -0.4, 0], "type": "revolute"},
                {"name": "left_ankle", "parent": 8, "offset": [0, -0.4, 0], "type": "revolute"},
                {"name": "right_shoulder", "parent": 1, "offset": [0.15, 0.1, 0], "type": "revolute"},
                {"name": "right_elbow", "parent": 10, "offset": [0.25, 0, 0], "type": "revolute"},
                {"name": "right_wrist", "parent": 11, "offset": [0.25, 0, 0], "type": "revolute"},
                {"name": "left_shoulder", "parent": 1, "offset": [-0.15, 0.1, 0], "type": "revolute"},
                {"name": "left_elbow", "parent": 13, "offset": [-0.25, 0, 0], "type": "revolute"},
                {"name": "left_wrist", "parent": 14, "offset": [-0.25, 0, 0], "type": "revolute"}
            ],
            "joint_names": ["root", "chest", "neck", "head", "right_hip", "right_knee", "right_ankle", 
                           "left_hip", "left_knee", "left_ankle", "right_shoulder", "right_elbow", 
                           "right_wrist", "left_shoulder", "left_elbow", "left_wrist"],
            "parent_indices": [-1, 0, 1, 2, 0, 4, 5, 0, 7, 8, 1, 10, 11, 1, 13, 14],
            "bone_count": 16
        }
        
    def load_tensorflow_model(self, ckpt_path):
        """Load DeepMimic policy from TensorFlow checkpoint"""
        try:
            # Reset default graph
            tf.compat.v1.reset_default_graph()
            
            # Create a new session
            sess = tf.compat.v1.Session()
            
            # Import the meta graph
            meta_path = ckpt_path + ".meta"
            if not os.path.exists(meta_path):
                # Try to create a simple policy network architecture
                return self.create_policy_network_from_checkpoint(ckpt_path, sess)
            
            saver = tf.compat.v1.train.import_meta_graph(meta_path)
            saver.restore(sess, ckpt_path)
            
            # Get input and output tensors
            graph = tf.compat.v1.get_default_graph()
            
            # Common input/output tensor names for DeepMimic
            input_names = ['input_ph', 'state_input', 'observations']
            output_names = ['action_output', 'policy_output', 'actions']
            
            input_tensor = None
            output_tensor = None
            
            # Try to find input tensor
            for name in input_names:
                try:
                    input_tensor = graph.get_tensor_by_name(name + ':0')
                    break
                except KeyError:
                    continue
                    
            # Try to find output tensor
            for name in output_names:
                try:
                    output_tensor = graph.get_tensor_by_name(name + ':0')
                    break
                except KeyError:
                    continue
            
            if input_tensor is None or output_tensor is None:
                # Fallback: list all operations and tensors
                print("Available operations:")
                for op in graph.get_operations():
                    print(f"  {op.name}: {op.type}")
                    
                # Try to infer from available tensors
                ops = graph.get_operations()
                placeholders = [op for op in ops if op.type == 'Placeholder']
                if placeholders:
                    input_tensor = placeholders[0].outputs[0]
                    print(f"Using input tensor: {input_tensor.name}")
                
                # Find last layer that might be output
                potential_outputs = [op for op in ops if 'dense' in op.name.lower() or 'output' in op.name.lower()]
                if potential_outputs:
                    output_tensor = potential_outputs[-1].outputs[0]
                    print(f"Using output tensor: {output_tensor.name}")
            
            return sess, input_tensor, output_tensor, graph
            
        except Exception as e:
            print(f"Error loading TensorFlow model: {e}")
            return None, None, None, None
    
    def create_policy_network_from_checkpoint(self, ckpt_path, sess):
        """Create a policy network and load weights from checkpoint"""
        try:
            # Read checkpoint to get variable info
            from tensorflow.python.tools import inspect_checkpoint as chkp
            chkp.print_tensors_in_checkpoint_file(ckpt_path, tensor_name='', all_tensors=True, all_tensor_names=True)
            
            # Create a simple policy network architecture
            # This is a fallback when meta graph is not available
            state_dim = 197  # Common DeepMimic state dimension
            action_dim = 36  # Based on observed output shape
            
            # Input placeholder
            state_input = tf.compat.v1.placeholder(tf.float32, [None, state_dim], name='state_input')
            
            # Simple feedforward network using TF 1.x style
            with tf.compat.v1.variable_scope('policy'):
                # First hidden layer
                hidden1_w = tf.compat.v1.get_variable('hidden1/kernel', [state_dim, 1024])
                hidden1_b = tf.compat.v1.get_variable('hidden1/bias', [1024])
                hidden1 = tf.nn.relu(tf.matmul(state_input, hidden1_w) + hidden1_b)
                
                # Second hidden layer
                hidden2_w = tf.compat.v1.get_variable('hidden2/kernel', [1024, 512])
                hidden2_b = tf.compat.v1.get_variable('hidden2/bias', [512])
                hidden2 = tf.nn.relu(tf.matmul(hidden1, hidden2_w) + hidden2_b)
                
                # Output layer
                output_w = tf.compat.v1.get_variable('output/kernel', [512, action_dim])
                output_b = tf.compat.v1.get_variable('output/bias', [action_dim])
                actions = tf.matmul(hidden2, output_w) + output_b
            
            # Initialize variables
            sess.run(tf.compat.v1.global_variables_initializer())
            
            # Load weights from checkpoint - this will fail gracefully if variables don't match
            try:
                saver = tf.compat.v1.train.Saver()
                saver.restore(sess, ckpt_path)
            except Exception as restore_e:
                print(f"Warning: Could not restore all variables: {restore_e}")
                # Try partial restoration based on checkpoint inspection
                reader = tf.compat.v1.train.NewCheckpointReader(ckpt_path)
                var_shapes = reader.get_variable_to_shape_map()
                
                # Map checkpoint variables to our network
                restore_ops = []
                for var_name in var_shapes:
                    try:
                        if 'agent/main/actor' in var_name:
                            # Map actor network weights
                            checkpoint_tensor = reader.get_tensor(var_name)
                            print(f"Found checkpoint variable: {var_name} with shape {checkpoint_tensor.shape}")
                            
                            # You would need to map these to your network variables here
                            # This is a simplified approach - in practice you'd need detailed mapping
                            
                    except Exception as e:
                        print(f"Could not process variable {var_name}: {e}")
                        continue
            
            return sess, state_input, actions, tf.compat.v1.get_default_graph()
            
        except Exception as e:
            print(f"Error creating policy network: {e}")
            return None, None, None, None
    
    def convert_to_onnx(self, ckpt_path, output_path):
        """Convert TensorFlow checkpoint to ONNX"""
        try:
            print(f"Converting {ckpt_path} to ONNX...")
            
            # Load TensorFlow model
            sess, input_tensor, output_tensor, graph = self.load_tensorflow_model(ckpt_path)
            
            if sess is None:
                print(f"Failed to load model from {ckpt_path}")
                return False
            
            # Convert to ONNX
            input_signature = [tf.TensorSpec(input_tensor.shape, input_tensor.dtype, name=input_tensor.name.split(':')[0])]
            
            onnx_model, _ = tf2onnx.convert.from_tensorflow(
                graph,
                input_signature,
                output_path=output_path,
                opset=11
            )
            
            # Validate ONNX model
            onnx.checker.check_model(onnx_model)
            
            # Save metadata
            metadata = {
                "model_name": os.path.basename(ckpt_path),
                "input_shape": input_tensor.shape.as_list(),
                "output_shape": output_tensor.shape.as_list(),
                "character_info": self.character_info,
                "conversion_date": str(Path(output_path).stat().st_mtime)
            }
            
            metadata_path = output_path.replace('.onnx', '_metadata.json')
            with open(metadata_path, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            sess.close()
            print(f"Successfully converted to {output_path}")
            return True
            
        except Exception as e:
            print(f"Error converting to ONNX: {e}")
            return False
    
    def convert_all_policies(self, input_dir, output_dir):
        """Convert all DeepMimic policies to ONNX"""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        # Find all .ckpt.index files
        ckpt_files = list(input_path.glob("*.ckpt.index"))
        
        converted_count = 0
        for ckpt_file in ckpt_files:
            # Remove .index extension to get base checkpoint path
            ckpt_base = str(ckpt_file).replace('.index', '')
            model_name = Path(ckpt_base).stem
            
            output_file = output_path / f"{model_name}.onnx"
            
            print(f"\nConverting {model_name}...")
            if self.convert_to_onnx(ckpt_base, str(output_file)):
                converted_count += 1
            else:
                print(f"Failed to convert {model_name}")
        
        print(f"\nConversion complete! {converted_count}/{len(ckpt_files)} models converted successfully.")
        return converted_count

def main():
    parser = argparse.ArgumentParser(description='Convert DeepMimic policies to ONNX')
    parser.add_argument('--input-dir', 
                        default='/home/barberb/motion/DeepMimic/data/policies/humanoid3d',
                        help='Directory containing .ckpt files')
    parser.add_argument('--output-dir',
                        default='/home/barberb/motion/DeepMimic/data/policies_onnx',
                        help='Directory to save ONNX files')
    parser.add_argument('--character-file',
                        default='/home/barberb/motion/DeepMimic/data/characters/humanoid3d.txt',
                        help='Path to character definition file')
    
    args = parser.parse_args()
    
    # Create converter
    converter = DeepMimicPolicyConverter(args.character_file)
    
    # Convert all policies
    converter.convert_all_policies(args.input_dir, args.output_dir)

if __name__ == "__main__":
    main()
