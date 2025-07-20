#!/usr/bin/env python3
"""
Simple DeepMimic to ONNX converter that directly reads checkpoint weights
and creates a compatible ONNX model
"""

import os
import sys
import tensorflow as tf
tf.compat.v1.disable_eager_execution()
import numpy as np
import onnx
from onnx import helper, numpy_helper
import argparse
import json
from pathlib import Path

def read_checkpoint_weights(ckpt_path):
    """Read weights directly from TensorFlow checkpoint"""
    reader = tf.compat.v1.train.NewCheckpointReader(ckpt_path)
    var_shapes = reader.get_variable_to_shape_map()
    
    weights = {}
    for var_name in var_shapes:
        # Only load actor network weights
        if 'agent/main/actor' in var_name and ('kernel' in var_name or 'bias' in var_name):
            try:
                # Simplify the name for easier processing
                simple_name = var_name.replace('agent/main/actor/', '').replace(':0', '')
                weights[simple_name] = reader.get_tensor(var_name)
                print(f"Loaded: {simple_name} {weights[simple_name].shape}")
            except Exception as e:
                print(f"Could not load {var_name}: {e}")
    
    return weights

def create_onnx_from_weights(weights, model_name):
    """Create ONNX model directly from checkpoint weights"""
    
    # Extract actor network weights in correct order
    actor_layers = []
    
    # Look for actor layers in order: 0/dense, 1/dense, dense (output)
    layer_names = ['0/dense', '1/dense', 'dense']
    
    for layer_name in layer_names:
        kernel_key = f'{layer_name}/kernel'
        bias_key = f'{layer_name}/bias'
        
        if kernel_key in weights and bias_key in weights:
            kernel = weights[kernel_key]
            bias = weights[bias_key]
            actor_layers.append((layer_name, kernel, bias))
            print(f"Found actor layer: {layer_name} -> kernel {kernel.shape}, bias {bias.shape}")
    
    if not actor_layers:
        raise ValueError("No valid actor layers found in checkpoint")
    
    # Get input/output dimensions from first and last layers
    input_dim = actor_layers[0][1].shape[0]  # First layer input size
    output_dim = actor_layers[-1][1].shape[1]  # Last layer output size
    
    print(f"Creating ONNX model: input_dim={input_dim}, output_dim={output_dim}")
    
    # Create ONNX nodes
    nodes = []
    initializers = []
    
    # Input
    input_tensor = helper.make_tensor_value_info('input', onnx.TensorProto.FLOAT, [None, input_dim])
    
    current_input = 'input'
    
    for i, (layer_name, kernel, bias) in enumerate(actor_layers):
        layer_prefix = f'layer_{i}'
        
        # Add weight and bias as initializers (no transpose needed for ONNX)
        weight_tensor = numpy_helper.from_array(kernel, f'{layer_prefix}_weight')
        bias_tensor = numpy_helper.from_array(bias, f'{layer_prefix}_bias')
        initializers.extend([weight_tensor, bias_tensor])
        
        # Create MatMul node
        matmul_output = f'{layer_prefix}_matmul'
        matmul_node = helper.make_node(
            'MatMul',
            inputs=[current_input, f'{layer_prefix}_weight'],
            outputs=[matmul_output],
            name=f'{layer_prefix}_matmul'
        )
        nodes.append(matmul_node)
        
        # Create Add node (bias)
        add_output = f'{layer_prefix}_add'
        add_node = helper.make_node(
            'Add',
            inputs=[matmul_output, f'{layer_prefix}_bias'],
            outputs=[add_output],
            name=f'{layer_prefix}_add'
        )
        nodes.append(add_node)
        
        # Add activation (ReLU for hidden layers, none for output)
        if i < len(actor_layers) - 1:  # Not the last layer
            relu_output = f'{layer_prefix}_relu'
            relu_node = helper.make_node(
                'Relu',
                inputs=[add_output],
                outputs=[relu_output],
                name=f'{layer_prefix}_relu'
            )
            nodes.append(relu_node)
            current_input = relu_output
        else:
            current_input = add_output
    
    # Output
    output_tensor = helper.make_tensor_value_info(current_input, onnx.TensorProto.FLOAT, [None, output_dim])
    
    # Create the graph
    graph = helper.make_graph(
        nodes,
        f'{model_name}_policy',
        [input_tensor],
        [output_tensor],
        initializers
    )
    
    # Create the model with compatible versions
    model = helper.make_model(graph, producer_name='deepmimic-converter')
    
    # Set compatible opset and IR versions for ONNX Runtime 1.14
    model.opset_import[0].version = 9  # Use opset 9 for better compatibility
    model.ir_version = 6  # Set IR version to 6 for compatibility with older runtimes
    
    # Check the model
    onnx.checker.check_model(model)
    
    return model

def convert_checkpoint_to_onnx(ckpt_path, output_path):
    """Convert a single checkpoint to ONNX"""
    try:
        print(f"Converting {ckpt_path} to ONNX...")
        
        # Read checkpoint weights
        weights = read_checkpoint_weights(ckpt_path)
        
        if not weights:
            print("No weights found in checkpoint")
            return False
        
        # Extract model name
        model_name = os.path.basename(ckpt_path).replace('.ckpt', '')
        
        # Create ONNX model
        onnx_model = create_onnx_from_weights(weights, model_name)
        
        # Save ONNX model
        onnx.save(onnx_model, output_path)
        
        print(f"Successfully converted to {output_path}")
        return True
        
    except Exception as e:
        print(f"Error converting {ckpt_path}: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    parser = argparse.ArgumentParser(description='Convert DeepMimic checkpoints to ONNX')
    parser.add_argument('--input-dir', 
                        default='/home/barberb/motion/DeepMimic/data/policies/humanoid3d',
                        help='Directory containing .ckpt files')
    parser.add_argument('--output-dir',
                        default='/home/barberb/motion/DeepMimic/data/policies_onnx',
                        help='Directory to save ONNX files')
    
    args = parser.parse_args()
    
    input_path = Path(args.input_dir)
    output_path = Path(args.output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Find all .ckpt.index files
    ckpt_files = list(input_path.glob("*.ckpt.index"))
    
    if not ckpt_files:
        print(f"No checkpoint files found in {input_path}")
        return
    
    converted_count = 0
    for ckpt_file in ckpt_files:
        # Remove .index extension to get base checkpoint path
        ckpt_base = str(ckpt_file).replace('.index', '')
        model_name = Path(ckpt_base).stem
        
        output_file = output_path / f"{model_name}.onnx"
        
        print(f"\nConverting {model_name}...")
        if convert_checkpoint_to_onnx(ckpt_base, str(output_file)):
            converted_count += 1
        else:
            print(f"Failed to convert {model_name}")
    
    print(f"\nConversion complete! {converted_count}/{len(ckpt_files)} models converted successfully.")

if __name__ == "__main__":
    main()
