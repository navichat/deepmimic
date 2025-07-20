#!/usr/bin/env python3
"""
DeepMimic Model Validation and Testing Framework

This script creates test data and validates that TensorFlow outputs match
ONNX Runtime outputs for DeepMimic policies. It generates reference data
that can be used to validate the JavaScript implementation.
"""

import os
import sys
import json
import numpy as np
import tensorflow as tf
import onnx
import onnxruntime as ort
from pathlib import Path
import argparse
import hashlib
from datetime import datetime

class DeepMimicModelValidator:
    def __init__(self, test_output_dir="validation_results"):
        self.test_output_dir = Path(test_output_dir)
        self.test_output_dir.mkdir(exist_ok=True)
        
        # Test configuration
        self.test_cases = {
            "zero_state": "All zeros state vector",
            "default_pose": "Default humanoid pose",
            "random_normal": "Random normal distribution",
            "walking_state": "Simulated walking state",
            "extreme_values": "Edge case with extreme values"
        }
        
        self.tolerance = {
            "absolute": 1e-5,
            "relative": 1e-4
        }
        
        # Store validation results
        self.validation_results = {}
        
    def create_test_states(self, state_dim=197):
        """Create various test state vectors for validation"""
        test_states = {}
        
        # Zero state
        test_states["zero_state"] = np.zeros(state_dim, dtype=np.float32)
        
        # Default humanoid pose
        default_state = np.zeros(state_dim, dtype=np.float32)
        default_state[1] = 1.0  # Y position (height)
        default_state[6] = 1.0  # Quaternion W component
        test_states["default_pose"] = default_state
        
        # Random normal distribution
        np.random.seed(42)  # For reproducibility
        test_states["random_normal"] = np.random.normal(0, 0.1, state_dim).astype(np.float32)
        
        # Simulated walking state
        walking_state = np.zeros(state_dim, dtype=np.float32)
        walking_state[0] = 0.0    # X position
        walking_state[1] = 1.0    # Y position
        walking_state[2] = 0.0    # Z position
        walking_state[3:7] = [0, 0, 0, 1]  # Root rotation (quaternion)
        walking_state[7] = 1.0    # Forward velocity
        walking_state[8] = 0.0    # Vertical velocity
        walking_state[9] = 0.0    # Lateral velocity
        # Add some joint positions for walking
        for i in range(13, min(50, state_dim), 3):
            walking_state[i] = np.sin(i * 0.1) * 0.1  # Small oscillations
        test_states["walking_state"] = walking_state
        
        # Extreme values (within reasonable bounds)
        extreme_state = np.zeros(state_dim, dtype=np.float32)
        extreme_state[0] = 10.0   # Large X position
        extreme_state[1] = 5.0    # High Y position
        extreme_state[7] = 5.0    # High velocity
        extreme_state[10:20] = 1.0  # Some large joint values
        test_states["extreme_values"] = extreme_state
        
        return test_states
    
    def load_tensorflow_model(self, ckpt_path):
        """Load TensorFlow model from checkpoint"""
        try:
            tf.compat.v1.reset_default_graph()
            sess = tf.compat.v1.Session()
            
            # Try to load meta graph
            meta_path = ckpt_path + ".meta"
            if os.path.exists(meta_path):
                saver = tf.compat.v1.train.import_meta_graph(meta_path)
                saver.restore(sess, ckpt_path)
                graph = tf.compat.v1.get_default_graph()
                
                # Find input and output tensors
                input_tensor = self.find_input_tensor(graph)
                output_tensor = self.find_output_tensor(graph)
                
                return sess, input_tensor, output_tensor, graph
            else:
                print(f"Meta graph not found for {ckpt_path}, creating fallback model")
                return self.create_fallback_model(ckpt_path, sess)
                
        except Exception as e:
            print(f"Error loading TensorFlow model: {e}")
            return None, None, None, None
    
    def find_input_tensor(self, graph):
        """Find the input tensor in the graph"""
        input_names = ['input_ph', 'state_input', 'observations', 'Placeholder']
        
        for name in input_names:
            try:
                return graph.get_tensor_by_name(name + ':0')
            except KeyError:
                continue
        
        # Fallback: find any placeholder
        for op in graph.get_operations():
            if op.type == 'Placeholder':
                print(f"Using placeholder: {op.name}")
                return op.outputs[0]
        
        raise ValueError("Could not find input tensor")
    
    def find_output_tensor(self, graph):
        """Find the output tensor in the graph"""
        output_names = ['action_output', 'policy_output', 'actions', 'output']
        
        for name in output_names:
            try:
                return graph.get_tensor_by_name(name + ':0')
            except KeyError:
                continue
        
        # Fallback: find likely output operations
        ops = graph.get_operations()
        dense_ops = [op for op in ops if 'dense' in op.name.lower() or 'output' in op.name.lower()]
        if dense_ops:
            print(f"Using output: {dense_ops[-1].name}")
            return dense_ops[-1].outputs[0]
        
        raise ValueError("Could not find output tensor")
    
    def create_fallback_model(self, ckpt_path, sess):
        """Create a fallback model when meta graph is not available"""
        # This is a simplified version - in practice you'd need the exact architecture
        state_dim = 197
        action_dim = 48  # Typical for humanoid
        
        input_tensor = tf.compat.v1.placeholder(tf.float32, [None, state_dim], name='state_input')
        
        with tf.compat.v1.variable_scope('policy'):
            hidden1 = tf.compat.v1.layers.dense(input_tensor, 512, activation=tf.nn.relu, name='hidden1')
            hidden2 = tf.compat.v1.layers.dense(hidden1, 256, activation=tf.nn.relu, name='hidden2')
            output_tensor = tf.compat.v1.layers.dense(hidden2, action_dim, name='output')
        
        sess.run(tf.compat.v1.global_variables_initializer())
        
        try:
            saver = tf.compat.v1.train.Saver()
            saver.restore(sess, ckpt_path)
        except Exception as e:
            print(f"Warning: Could not restore weights: {e}")
        
        return sess, input_tensor, output_tensor, tf.compat.v1.get_default_graph()
    
    def run_tensorflow_inference(self, sess, input_tensor, output_tensor, test_states):
        """Run inference using TensorFlow"""
        tf_results = {}
        
        for test_name, state in test_states.items():
            try:
                # Reshape to add batch dimension
                batch_state = state.reshape(1, -1)
                
                # Run inference
                actions = sess.run(output_tensor, feed_dict={input_tensor: batch_state})
                
                # Store results
                tf_results[test_name] = {
                    "input_shape": batch_state.shape,
                    "output_shape": actions.shape,
                    "output": actions.flatten().tolist(),
                    "input_hash": hashlib.md5(batch_state.tobytes()).hexdigest(),
                    "output_hash": hashlib.md5(actions.tobytes()).hexdigest()
                }
                
                print(f"TensorFlow {test_name}: input {batch_state.shape} -> output {actions.shape}")
                
            except Exception as e:
                print(f"Error running TensorFlow inference for {test_name}: {e}")
                tf_results[test_name] = {"error": str(e)}
        
        return tf_results
    
    def run_onnx_inference(self, onnx_path, test_states):
        """Run inference using ONNX Runtime (CPU)"""
        try:
            # Load ONNX model
            session = ort.InferenceSession(onnx_path, providers=['CPUExecutionProvider'])
            
            input_name = session.get_inputs()[0].name
            output_name = session.get_outputs()[0].name
            
            onnx_results = {}
            
            for test_name, state in test_states.items():
                try:
                    # Reshape to add batch dimension
                    batch_state = state.reshape(1, -1).astype(np.float32)
                    
                    # Run inference
                    outputs = session.run([output_name], {input_name: batch_state})
                    actions = outputs[0]
                    
                    # Store results
                    onnx_results[test_name] = {
                        "input_shape": batch_state.shape,
                        "output_shape": actions.shape,
                        "output": actions.flatten().tolist(),
                        "input_hash": hashlib.md5(batch_state.tobytes()).hexdigest(),
                        "output_hash": hashlib.md5(actions.tobytes()).hexdigest()
                    }
                    
                    print(f"ONNX {test_name}: input {batch_state.shape} -> output {actions.shape}")
                    
                except Exception as e:
                    print(f"Error running ONNX inference for {test_name}: {e}")
                    onnx_results[test_name] = {"error": str(e)}
            
            return onnx_results
            
        except Exception as e:
            print(f"Error loading ONNX model {onnx_path}: {e}")
            return {}
    
    def compare_outputs(self, tf_results, onnx_results):
        """Compare TensorFlow and ONNX outputs"""
        comparison_results = {}
        
        for test_name in tf_results:
            if test_name not in onnx_results:
                comparison_results[test_name] = {"status": "missing_onnx"}
                continue
            
            tf_result = tf_results[test_name]
            onnx_result = onnx_results[test_name]
            
            # Check for errors
            if "error" in tf_result or "error" in onnx_result:
                comparison_results[test_name] = {
                    "status": "error",
                    "tf_error": tf_result.get("error"),
                    "onnx_error": onnx_result.get("error")
                }
                continue
            
            # Compare outputs
            tf_output = np.array(tf_result["output"])
            onnx_output = np.array(onnx_result["output"])
            
            # Calculate differences
            abs_diff = np.abs(tf_output - onnx_output)
            rel_diff = np.abs(abs_diff / (np.abs(tf_output) + 1e-8))
            
            max_abs_diff = np.max(abs_diff)
            max_rel_diff = np.max(rel_diff)
            mean_abs_diff = np.mean(abs_diff)
            mean_rel_diff = np.mean(rel_diff)
            
            # Determine if within tolerance
            abs_ok = max_abs_diff < self.tolerance["absolute"]
            rel_ok = max_rel_diff < self.tolerance["relative"]
            
            comparison_results[test_name] = {
                "status": "pass" if (abs_ok and rel_ok) else "fail",
                "max_absolute_diff": float(max_abs_diff),
                "max_relative_diff": float(max_rel_diff),
                "mean_absolute_diff": float(mean_abs_diff),
                "mean_relative_diff": float(mean_rel_diff),
                "within_tolerance": abs_ok and rel_ok,
                "input_hash_match": tf_result["input_hash"] == onnx_result["input_hash"],
                "tf_output_shape": tf_result["output_shape"],
                "onnx_output_shape": onnx_result["output_shape"]
            }
        
        return comparison_results
    
    def generate_javascript_test_data(self, test_states, tf_results, onnx_results):
        """Generate test data for JavaScript validation"""
        js_test_data = {
            "metadata": {
                "generated_at": datetime.now().isoformat(),
                "tolerance": self.tolerance,
                "description": "Test data for validating JavaScript ONNX inference"
            },
            "test_cases": {}
        }
        
        for test_name, state in test_states.items():
            if test_name in tf_results and test_name in onnx_results:
                tf_result = tf_results[test_name]
                onnx_result = onnx_results[test_name]
                
                if "error" not in tf_result and "error" not in onnx_result:
                    js_test_data["test_cases"][test_name] = {
                        "description": self.test_cases.get(test_name, ""),
                        "input": state.tolist(),
                        "expected_output": onnx_result["output"],  # Use ONNX as reference
                        "tensorflow_output": tf_result["output"],
                        "input_shape": [1, len(state)],
                        "output_shape": onnx_result["output_shape"]
                    }
        
        return js_test_data
    
    def validate_model(self, ckpt_path, onnx_path, model_name):
        """Validate a single model"""
        print(f"\n=== Validating {model_name} ===")
        print(f"TensorFlow checkpoint: {ckpt_path}")
        print(f"ONNX model: {onnx_path}")
        
        # Create test states
        test_states = self.create_test_states()
        
        # Load and test TensorFlow model
        print("\nLoading TensorFlow model...")
        sess, input_tensor, output_tensor, graph = self.load_tensorflow_model(ckpt_path)
        
        if sess is None:
            print("Failed to load TensorFlow model")
            return False
        
        print("Running TensorFlow inference...")
        tf_results = self.run_tensorflow_inference(sess, input_tensor, output_tensor, test_states)
        sess.close()
        
        # Test ONNX model
        if os.path.exists(onnx_path):
            print("Running ONNX inference...")
            onnx_results = self.run_onnx_inference(onnx_path, test_states)
        else:
            print(f"ONNX model not found: {onnx_path}")
            onnx_results = {}
        
        # Compare results
        if onnx_results:
            print("Comparing outputs...")
            comparison_results = self.compare_outputs(tf_results, onnx_results)
            
            # Generate JavaScript test data
            js_test_data = self.generate_javascript_test_data(test_states, tf_results, onnx_results)
            
            # Save results
            result_data = {
                "model_name": model_name,
                "timestamp": datetime.now().isoformat(),
                "test_states": {name: state.tolist() for name, state in test_states.items()},
                "tensorflow_results": tf_results,
                "onnx_results": onnx_results,
                "comparison": comparison_results,
                "javascript_test_data": js_test_data,
                "validation_summary": self.create_validation_summary(comparison_results)
            }
            
            # Save to files
            result_file = self.test_output_dir / f"{model_name}_validation.json"
            with open(result_file, 'w') as f:
                json.dump(result_data, f, indent=2)
            
            # Save JavaScript test data separately
            js_test_file = self.test_output_dir / f"{model_name}_js_test_data.json"
            with open(js_test_file, 'w') as f:
                json.dump(js_test_data, f, indent=2)
            
            print(f"Results saved to {result_file}")
            print(f"JavaScript test data saved to {js_test_file}")
            
            # Store in instance for summary
            self.validation_results[model_name] = result_data
            
            return self.print_validation_summary(model_name, comparison_results)
        else:
            print("No ONNX results to compare")
            return False
    
    def create_validation_summary(self, comparison_results):
        """Create a summary of validation results"""
        total_tests = len(comparison_results)
        passed_tests = sum(1 for result in comparison_results.values() 
                          if result.get("status") == "pass")
        failed_tests = sum(1 for result in comparison_results.values() 
                          if result.get("status") == "fail")
        error_tests = sum(1 for result in comparison_results.values() 
                         if result.get("status") == "error")
        
        return {
            "total_tests": total_tests,
            "passed": passed_tests,
            "failed": failed_tests,
            "errors": error_tests,
            "pass_rate": passed_tests / total_tests if total_tests > 0 else 0
        }
    
    def print_validation_summary(self, model_name, comparison_results):
        """Print validation summary"""
        summary = self.create_validation_summary(comparison_results)
        
        print(f"\n--- Validation Summary for {model_name} ---")
        print(f"Total tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed']}")
        print(f"Failed: {summary['failed']}")
        print(f"Errors: {summary['errors']}")
        print(f"Pass rate: {summary['pass_rate']*100:.1f}%")
        
        # Print detailed results
        for test_name, result in comparison_results.items():
            status = result["status"]
            if status == "pass":
                print(f"  ✅ {test_name}: PASS")
            elif status == "fail":
                print(f"  ❌ {test_name}: FAIL (max_abs_diff: {result['max_absolute_diff']:.2e}, "
                      f"max_rel_diff: {result['max_relative_diff']:.2e})")
            else:
                print(f"  🚫 {test_name}: ERROR")
        
        return summary['pass_rate'] == 1.0
    
    def validate_all_models(self, input_dir, onnx_dir):
        """Validate all models in the directories"""
        input_path = Path(input_dir)
        onnx_path = Path(onnx_dir)
        
        # Find all checkpoint files
        ckpt_files = list(input_path.glob("*.ckpt.index"))
        
        print(f"Found {len(ckpt_files)} models to validate")
        
        validation_summary = {}
        
        for ckpt_file in ckpt_files:
            ckpt_base = str(ckpt_file).replace('.index', '')
            model_name = Path(ckpt_base).stem
            onnx_file = onnx_path / f"{model_name}.onnx"
            
            try:
                success = self.validate_model(ckpt_base, str(onnx_file), model_name)
                validation_summary[model_name] = "PASS" if success else "FAIL"
            except Exception as e:
                print(f"Error validating {model_name}: {e}")
                validation_summary[model_name] = f"ERROR: {e}"
        
        # Print overall summary
        self.print_overall_summary(validation_summary)
        
        # Save overall summary
        summary_file = self.test_output_dir / "validation_summary.json"
        with open(summary_file, 'w') as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "models": validation_summary,
                "detailed_results": self.validation_results
            }, f, indent=2)
        
        print(f"Overall summary saved to {summary_file}")
        
        return validation_summary
    
    def print_overall_summary(self, validation_summary):
        """Print overall validation summary"""
        total_models = len(validation_summary)
        passed_models = sum(1 for status in validation_summary.values() if status == "PASS")
        failed_models = sum(1 for status in validation_summary.values() if status == "FAIL")
        error_models = sum(1 for status in validation_summary.values() if "ERROR" in status)
        
        print(f"\n{'='*60}")
        print(f"OVERALL VALIDATION SUMMARY")
        print(f"{'='*60}")
        print(f"Total models: {total_models}")
        print(f"Passed: {passed_models}")
        print(f"Failed: {failed_models}")
        print(f"Errors: {error_models}")
        print(f"Success rate: {passed_models/total_models*100:.1f}%")
        print(f"{'='*60}")
        
        for model_name, status in validation_summary.items():
            status_symbol = "✅" if status == "PASS" else "❌" if status == "FAIL" else "🚫"
            print(f"  {status_symbol} {model_name}: {status}")

def main():
    parser = argparse.ArgumentParser(description='Validate DeepMimic model conversion')
    parser.add_argument('--tf-dir', 
                        default='/home/barberb/motion/DeepMimic/data/policies/humanoid3d',
                        help='Directory containing TensorFlow .ckpt files')
    parser.add_argument('--onnx-dir',
                        default='/home/barberb/motion/DeepMimic/data/policies_onnx',
                        help='Directory containing ONNX files')
    parser.add_argument('--output-dir',
                        default='validation_results',
                        help='Directory to save validation results')
    parser.add_argument('--model',
                        help='Validate specific model only')
    
    args = parser.parse_args()
    
    # Create validator
    validator = DeepMimicModelValidator(args.output_dir)
    
    if args.model:
        # Validate single model
        ckpt_path = Path(args.tf_dir) / f"{args.model}.ckpt"
        onnx_path = Path(args.onnx_dir) / f"{args.model}.onnx"
        validator.validate_model(str(ckpt_path), str(onnx_path), args.model)
    else:
        # Validate all models
        validator.validate_all_models(args.tf_dir, args.onnx_dir)

if __name__ == "__main__":
    main()
