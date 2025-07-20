#!/usr/bin/env python3
"""
Simple ONNX model validation and test data generation
"""

import os
import numpy as np
import onnxruntime as ort
import json
from pathlib import Path

def generate_test_data_for_onnx(onnx_path, num_test_cases=5):
    """Generate test input/output data for an ONNX model"""
    
    # Load ONNX model
    session = ort.InferenceSession(onnx_path)
    
    # Get input/output info
    input_info = session.get_inputs()[0]
    output_info = session.get_outputs()[0]
    
    input_name = input_info.name
    input_shape = input_info.shape
    output_name = output_info.name
    output_shape = output_info.shape
    
    # Generate test cases
    test_cases = []
    
    for i in range(num_test_cases):
        # Generate random input in reasonable range for DeepMimic
        # State vectors typically contain normalized values
        np.random.seed(42 + i)  # Reproducible random data
        input_data = np.random.normal(0, 0.5, (1, input_shape[1])).astype(np.float32)
        
        # Run inference
        outputs = session.run([output_name], {input_name: input_data})
        output_data = outputs[0]
        
        test_case = {
            'input': input_data.tolist(),
            'expected_output': output_data.tolist(),
            'input_shape': list(input_data.shape),
            'output_shape': list(output_data.shape)
        }
        test_cases.append(test_case)
    
    return {
        'model_info': {
            'input_name': input_name,
            'output_name': output_name,
            'input_shape': input_shape,
            'output_shape': output_shape
        },
        'test_cases': test_cases
    }

def validate_all_onnx_models(onnx_dir, output_dir):
    """Validate all ONNX models and generate test data"""
    
    onnx_path = Path(onnx_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Find all ONNX files
    onnx_files = list(onnx_path.glob("*.onnx"))
    
    results = {}
    all_test_data = {}
    
    for onnx_file in onnx_files:
        model_name = onnx_file.stem
        print(f"\nValidating {model_name}...")
        
        try:
            # Test ONNX model loading and inference
            test_data = generate_test_data_for_onnx(str(onnx_file))
            
            # Save individual test data file
            test_file = output_path / f"{model_name}_test_data.json"
            with open(test_file, 'w') as f:
                json.dump(test_data, f, indent=2)
            
            results[model_name] = {
                'status': 'SUCCESS',
                'input_shape': test_data['model_info']['input_shape'],
                'output_shape': test_data['model_info']['output_shape'],
                'test_cases': len(test_data['test_cases'])
            }
            
            all_test_data[model_name] = test_data
            
            print(f"  ✅ {model_name}: PASSED")
            print(f"     Input shape: {test_data['model_info']['input_shape']}")
            print(f"     Output shape: {test_data['model_info']['output_shape']}")
            print(f"     Test cases: {len(test_data['test_cases'])}")
            
        except Exception as e:
            print(f"  ❌ {model_name}: FAILED - {e}")
            results[model_name] = {
                'status': 'FAILED',
                'error': str(e)
            }
    
    # Save combined test data for JavaScript
    combined_file = output_path / "all_models_test_data.json"
    with open(combined_file, 'w') as f:
        json.dump(all_test_data, f, indent=2)
    
    # Save validation summary
    summary = {
        'total_models': len(onnx_files),
        'passed': len([r for r in results.values() if r['status'] == 'SUCCESS']),
        'failed': len([r for r in results.values() if r['status'] == 'FAILED']),
        'results': results,
        'success_rate': len([r for r in results.values() if r['status'] == 'SUCCESS']) / len(onnx_files) * 100
    }
    
    summary_file = output_path / "onnx_validation_summary.json"
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n" + "="*60)
    print("ONNX VALIDATION SUMMARY")
    print("="*60)
    print(f"Total models: {summary['total_models']}")
    print(f"Passed: {summary['passed']}")
    print(f"Failed: {summary['failed']}")
    print(f"Success rate: {summary['success_rate']:.1f}%")
    print("="*60)
    
    for model_name, result in results.items():
        status_icon = "✅" if result['status'] == 'SUCCESS' else "❌"
        print(f"  {status_icon} {model_name}: {result['status']}")
    
    print(f"\nTest data saved to: {output_path}")
    print(f"Combined test data: {combined_file}")
    
    return summary

def main():
    onnx_dir = "/home/barberb/motion/DeepMimic/data/policies_onnx"
    output_dir = "/home/barberb/motion/DeepMimic/data/policies_onnx/validation_results"
    
    summary = validate_all_onnx_models(onnx_dir, output_dir)

if __name__ == "__main__":
    main()
