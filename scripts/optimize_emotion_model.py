import coremltools as ct
import sys
import os

def optimize_emotion_classifier(model_path, output_path):
    print(f"Loading model from {model_path}")
    model = ct.models.MLModel(model_path)
    
    # Configure optimization options
    config = ct.ComputeUnit.ALL
    
    # Convert to floating point 16 for better performance
    model_fp16 = ct.convert(
        model,
        compute_units=config,
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS16
    )
    
    # Enable memory mapping for faster loading
    model_fp16.memory_map = True
    
    # Set compute precision to float16
    model_fp16.compute_precision = "FLOAT16"
    
    # Enable operation fusion for better performance
    model_fp16.operation_fusion = True
    
    # Set prediction options for optimized inference
    model_fp16.prediction_options = {
        "reduce_memory_usage": True,
        "enable_profiling": False,
        "prefer_compressed_matrices": True
    }
    
    # Save optimized model
    print(f"Saving optimized model to {output_path}")
    model_fp16.save(output_path)
    
    # Report model size
    original_size = os.path.getsize(model_path) / (1024 * 1024)
    optimized_size = os.path.getsize(output_path) / (1024 * 1024)
    print(f"Original model size: {original_size:.2f}MB")
    print(f"Optimized model size: {optimized_size:.2f}MB")
    print(f"Size reduction: {((original_size - optimized_size) / original_size) * 100:.2f}%")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python optimize_emotion_model.py input_model.mlmodel output_model.mlmodel")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    optimize_emotion_classifier(input_path, output_path)
