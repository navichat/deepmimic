import random
import numpy as np

def set_global_seeds(seed):
    try:
        import tensorflow as tf
    except ImportError:
        pass
    else:
        tf.compat.v1.set_random_seed(seed)
    np.random.seed(seed)
    random.seed(seed)
    return