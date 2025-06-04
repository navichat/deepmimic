import tensorflow.compat.v1 as tf

def manual_dense(inputs, units, activation=None, kernel_initializer=None, bias_initializer=None, name=None, reuse=None):
    """Manual dense layer implementation for Keras 3 compatibility"""
    if kernel_initializer is None:
        kernel_initializer = tf.compat.v1.initializers.glorot_uniform()
    if bias_initializer is None:
        bias_initializer = tf.compat.v1.initializers.zeros()

    input_size = inputs.get_shape().as_list()[-1]

    with tf.compat.v1.variable_scope(name or 'dense', reuse=reuse):
        weights = tf.compat.v1.get_variable(
            'kernel',
            shape=[input_size, units],
            initializer=kernel_initializer
        )
        biases = tf.compat.v1.get_variable(
            'bias',
            shape=[units],
            initializer=bias_initializer
        )

        output = tf.matmul(inputs, weights) + biases

        if activation is not None:
            output = activation(output)

        return output
