---
layout: post
author: David Sillman
title: Linear Regression in Rust with AutoGrad
---

&nbsp;&nbsp;&nbsp;&nbsp; I've spent the past two weeks just starting to get a handle
on how to use the popular low-level, memory-safe programming language Rust. In general,
it gives me C++ vibes when I'm programming in it. That said, I think that it could have
good potential as a machine learning development environment, so long as it is
supplied with the appropriate external libraries (or "crates," to use Rust's
terminology.)

<br>
&nbsp;&nbsp;&nbsp;&nbsp; So, to get a handle on how I could use Rust specifically
for machine learning purposes, I did some (very brief) research into what tools
might be useful. I knew that I wanted to make use of an _auto-differentiation_
tool, as this is essentially the bedrock of a machine learning dev environment.
Auto-differentiation allows us to compute partial derivatives of the output of
our models such that we can tweak and tune them into being better predictors. I looked
over three different auto-differentiation crates:

* [`easy-ml`](https://crates.io/crates/easy-ml) : This is actually a much more comprehensive
machine learning crate with lots of out-of-the-box machine learning implementations
which are easy to implement. It also contains a module,
[`differentiation`](https://docs.rs/easy-ml/1.8.1/easy_ml/differentiation/index.html)
which houses its auto-differentiation engine. This module could suffice for my purposes,
but I don't like the overhead of needing to install all of the extra bells and whistles
provided by `easy-ml` just to get access to its `differentiation` module. I'd rather
use a crate which contains only the necessary tools & traits for auto-differentiation
in particular.
* [`autodiff`](https://crates.io/crates/autodiff) : The problem with using this crate
in particular is that it is mostly tailored toward calculus on scalar functions,
whereas most machine learning applications require higher-dimensional differentiation
in the form of vectors, matrices and scalars. I don't know if `autodiff` is necessarily
incapable of implementing these features, but most of their examples and documentation
emphasize their scalar equivalents.
* [`autograd`](https://crates.io/crates/autograd) : Of the above two alternatives,
`autograd` certainly takes the cake for popularity and satisfies my complaints
about the other two. The crate implements auto-differentiation  on the standard
Rust matrix/tensor crate, [`ndarray`](https://crates.io/crates/ndarray), which can
allow for maximal cross-compatibility with other matrix-related crates. Moreover, it
is very well documented and small enough for me to be able to scan the source code
to answer questions not addressed by the documentation. Moreover, it's easily extendible
for custom tensor operations and I/O pipelines.

&nbsp;&nbsp;&nbsp;&nbsp; So, I decided to go with `autograd` for my auto-differentiation
engine. I could have gone deeper into my research to find other alternatives, but
these three appeared to be the most popular (according to crates.io), and `autograd`
serves all of the basic purposes which I am looking for.

### Linear Regression as a Neural Network
&nbsp;&nbsp;&nbsp;&nbsp; The simplest machine learning application I could come
up with to test this crate out (which wasn't already done in their tutorials collection)
was a simple linear regression neural network. For those who don't know, a neural
network is essentially a statistical model which recursively applies a linear regression
and some nonlinear _activation_ function. So, if I wanted to use a neural network
for the purposes of a simple, one-dimensional linear regression, I would use a 1D
input layer connected directly to a 1D output layer with no activation function.
The weight parameter of the single neuron in this network corresponds to the slope
of our linear regression, while its bias parameter is the offset. This is why the
output equation of our model would look exactly like the formula for a line:

$$
y = mx + b \qquad \Leftrightarrow \qquad y = \text{weight}\cdot x + \text{bias}
$$

&nbsp;&nbsp;&nbsp;&nbsp; In a diagram, this linear regression model looks like the
neural network pictured below:

<br>
<img class="centered" width="360px" alt="1D Linear Reg Picture" src="/assets/images/1dlinregmodel.svg"/>

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Obviously, if this was all I wanted to use my auto-differentiation
engine for, it would be woefully overpowered, but this is just a simple "hello world."
More generally, if I really wanted (only) to implement a linear regression algorithm
in Rust, I would just use the [closed-form formula for a linear regression](https://en.wikipedia.org/wiki/Linear_regression#Least-squares_estimation_and_related_techniques) and use
`ndarray-linalg` for matrix multiplications and inverses to implement it. However,
in future, I'd like to construct more complicated neural models which will require the
full power of `autograd`, so this is a small proof-of-concept which allows me to get
comfortable with the crate.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Now that I have a basic idea of what sort of model I'm
going to be building, I can start writing some Rust code.

### Implementing the Model with AutoGrad
&nbsp;&nbsp;&nbsp;&nbsp; The main example from `autograd`'s GitHub repo with which
my project has the most overlap is the [`sine.rs`](https://github.com/raskr/rust-autograd/blob/master/examples/sine.rs)
example, which regresses a multi-layer perceptron (MLP) to the sine function.
Because I'm doing something simpler, I'll only be following it insofar as it is a
useful reference for how regression works generally in `autograd`.

The first thing I do is import a handful of modules from the crate:

<br>
```rust
  use autograd as ag;
  use ag::optimizers::*;
  use ag::optimizers::adam::Adam;
  use ag::prelude::*;
  use ag::tensors_ops::*;
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; The first of these just assigns a nickname, `ag`, which I can use in place of the
longer namespace, `autograd`. After that, I'm importing tools for optimizers, the
Adam optimizer specifically, some high-level traits from `autograd`'s prelude, and
the `tensor_ops` module.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Next, I create my `main` function, and start initializing the core engine of `autograd`:
the so-called `VariableEnvironment`, along with an instance of a random number generator.

<br>
```rust
fn main() {
    // Initialize VariableEnvironment and (default seed) RNG
    let mut env = ag::VariableEnvironment::new();
    let rng = ag::ndarray_ext::ArrayRng::<f32>::default();
    // --snip--
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; In short, the `VariableEnvironment` is a container which
manages all of the variables which we use in learning and keeps track of how they
change throughout the learning process. In setting it up, I register our two learned
parameters in the `VariableEnvironment`, which involves associating them with a name:

<br>
```rust
    // --snip--
    // Initializing our parameter tensors
    env.name("w").set(rng.standard_uniform(&[1, 1]));
    env.name("b").set(ag::ndarray_ext::zeros(&[1, 1]));
    // --snip--
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; With `env.name()`, we are registering a new `NamedVariableSlot` in the environment,
which we then immediately give an initial value with the `set()` method. The arguments
of the functions inside of the `set` call are each references to arrays of `usize`,
each of which state that we are initializing `w` with a $$1\times 1$$ tensor of
random values, and that we are initializing `b` with a $$1\times 1$$ tensor of zeros.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; So, our next step in initializing the model is creating an
instance of an optimizer which governs how we use the partial derivatives we compute
in order to reduce loss and predict outputs more accurately. We're using the Adam
optimizer for this, which we give some parameters to:

<br>
```rust
    // --snip--
    // Initializing our optimizer (Adam)
    let adam = Adam::new(0.01,  // Learning rate (alpha)
                         1e-08, // Error Toler. (epsilon)
                         0.9,   // First Moment decay (beta1)
                         0.999, // Second Moment decay (beta2)
                         env.default_namespace().current_var_ids(), // Variable IDs from VariableEnvironment namespace
                         &mut env,                                  // VariableEnvironment instance    
                         "linear_reg_adam");                        // Name string
    // --snip--
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; All of the parameters I've put in above are generally considered
to be the "default" parameters for most use cases of Adam, but I've beefed up the
learning rate ($$\alpha$$) by a factor of 10 to speed up learning on such a dimensionally
small model. It's also noteworthy that I need to provide the optimizer with the Variable
IDs from the `VariableEnvironment` (so it knows what our learned parameters are), as
well as a _mutable_ reference to the environment. We also supply it with a name.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Now I start thinking about the training process. For the purposes
of this project, I'd like to train the linear regressor in batches of size $$64$$, over the
course of $$1000$$ epochs (i.e. batches). So I just quickly define some constants for
these quantities:

<br>
```rust
    // Initializing training constants
    const N_EPOCHS : usize = 1000;
    const BATCHSIZE : usize = 64;
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; At this point, I'm almost ready to code up the training loop.
But it feels like I'm forgetting something; perhaps the actual training data itself?
Where am I getting that data from? Because we're working totally with a synthetic dataset
for this project, it suffices to define some "true" values we expect our network to learn,
then use those values (and some data noise) to generate data points as we train. So,
I define the parameters I'd like to learn:

<br>
```rust
    // Setting up the (synthetic) dataset
    let true_w = 2.5f32;
    let true_b = -1.0f32;
    let noise_scale = 0.5f32;
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Now we can jump into the meat of our algorithm: the training
loop. This consists of a `for`-loop to iterate over the epochs, along with the following
contents which I will explain:

<br>
```rust
    // --snip--
    for epoch in 0..N_EPOCHS {
        env.run(|ctx| {
            let x = standard_uniform(&[BATCHSIZE, 1], ctx) * 20. - 10.;     // Randomly generate input coords
            let w = ctx.variable("w");                                      // Retrieve variables
            let b = ctx.variable("b");
            let y = true_w * x + true_b +
                    standard_normal(&[BATCHSIZE, 1], ctx) * noise_scale;    // Compute expected output (w/ noise)

            let z = matmul(x, w) + b;                                       // Compute LinReg predictions

            let mean_loss = reduce_mean(square(z - y), &[0], false);                // Compute Mean Sq Error Loss
            let ns = ctx.default_namespace();
            let (vars, grads) = grad_helper(&[mean_loss], &ns);                     // Compute gradients for variables
            let update_op = adam.get_update_op(&vars, &grads, ctx);                 // Compute weight/bias change
            let results = ctx.evaluator().push(mean_loss).push(update_op).run();    // "Push" both loss and changes to evaluation buffer

            match epoch % 100 {
                0 => println!("Mean Loss (epoch {}) = {}", epoch, results[0].as_ref().unwrap()),    // Print training loss every 100 epochs
                _ => ()
            }
        });
    }
    // --snip--
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Here we note that we are passing a function to our `VariableEnvironment`
via the function `run()`. This function expects its argument to be a function with an argument
of a type called `Context`, which is often abbreviated as `ctx` in variable names,
which I use in the closure. Anything we run inside of the closure we pass to `env.run()`
is used to create a `Graph`, which is a component frequently seen in auto-differentiation
engines. Without getting into too many nitty-gritty details, you can think of this as a
graph where nodes are variables in our model, and we have arrows between them indicating
how data flows between them such that we can "trace back" how they interact with one another and
use this data to compute partial derivatives.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; So what does all of this mean for us? It means that anything we do
inside of `env.run()` will be "watched" by the graph so we can compute derivatives. Let's
take a look at what we do inside of the context closure, one digestible chunk at a time:

<br>
```rust
  let x = standard_uniform(&[BATCHSIZE, 1], ctx) * 20. - 10.;     // Randomly generate input coords
  let w = ctx.variable("w");                                      // Retrieve variables
  let b = ctx.variable("b");
  let y = true_w * x + true_b +
          standard_normal(&[BATCHSIZE, 1], ctx) * noise_scale;    // Compute expected output (w/ noise)

  let z = matmul(x, w) + b;                                       // Compute LinReg predictions
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; What we initially do is generate a tensor of uniformly-distributed
input coordinates, spread evenly on the interval $$(-10, 10)$$. Then, I call the
`variable()` function from the `Context` instance, which allows me to retrieve a variable
tensor by the name I assigned to it earlier on when I initialized it. The next thing I do
is generate the expected output for these data points according to the line formula,
to which I add a (scaled) tensor of Gaussian noise to add some realistic data noise like
we would see in a real dataset.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; On the last line, I assign to `z` what's normally called the
"forward propagation" of the network. That is, I take the tensor batch of input points and
propagate it through the model and compute the output which gives our model's prediction.
This is done through a matrix multiplication (via `matmul()` from the `tensor_ops` module)
after which we add our bias tensor variable `b`.

<br>
```rust
  let mean_loss = reduce_mean(square(z - y), &[0], false);                // Compute Mean Sq Error Loss
  let ns = ctx.default_namespace();
  let (vars, grads) = grad_helper(&[mean_loss], &ns);                     // Compute gradients for variables
  let update_op = adam.get_update_op(&vars, &grads, ctx);                 // Compute weight/bias change
  let results = ctx.evaluator().push(mean_loss).push(update_op).run();    // "Push" both loss and changes to evaluation buffer
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; In this next chunk, I start by computing the current loss
of the model on the current batch, storing the value in `mean_loss`. Because I'm
using Mean Squared Error (MSE) as our loss metric, I can compute it very simply by
constructing a tensor of the difference between our prediction and expectation (`z - y`),
squaring its elements (via `square()`), then, taking the average of the resulting tensor
in the form of a scalar (accomplished by `reduce_mean`). The extra arguments at the end of
`reduce_mean` are an array of the axes along which we're taking the mean (`&[0]`), and
`false` to indicate that we want to discard the axis we're taking the mean along, which
leaves us with a scalar.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; The next meaningful line is where we assign values to `vars` and
`grads` - this uses the function `grad_helper()` from the `optimizers` module, to
which I hand both an array of the loss variable(s) I'm trying to minimize (in our case,
`&[mean_loss]`, the MSE variable), as well as the namespace from our `Context` which
contains all of our learnable parameters (in our case, `w`, and `b` as variable tensors).

<br>
&nbsp;&nbsp;&nbsp;&nbsp; I then use the `adam` optimizer instance to call `adam.get_update_op()`,
which takes in references to the variables and their respective gradients, as well as the
`Context` instance, and returns the adjustments that need to be made to the variables
in order to reduce the loss, which I call `update_op`.

<br>
&nbsp;&nbsp;&nbsp;&nbsp;  In the next line, I call a sequence of functions in the form of
`ctx.evaluator().push().run()`. The `Context` instance contains an `Evaluator`, which
actually enacts the changes suggested by our optimizer. The pattern important here is
"pushing" values to the evaluator, then finally calling `run()` to turn those values
into instructions that get evaluated. In computer science, data structures that store
a set of instructions and only evaluate their output when it's necessary is known as a
"lazy data structure." This is why `autograd` is built upon a "Lazy Tensor" evaluation
engine - the results aren't explicitly computed (which can be costly) _until_ we push
them to the evaluator and call "run."

<br>
&nbsp;&nbsp;&nbsp;&nbsp; I initially had to ask; "why are we pushing our mean loss?"
After all, that's not necessary for any of the tensor updates. The main reason is so that
we can print out the _evaluated_ value of `mean_loss`. Because we computed `mean_loss` purely
with tensor variables, the resulting scalar is still a tensor variable and doesn't actually
contain a numeric value. Because I'd like to print out what error we have, I need to push
it to the evaluator and get that numeric value lazily. In the next line, I use a
`match` statement (which I like to think of as Rust's equivalent of a `switch` statement)
to print out the loss of the algorithm every 100 epochs.

<br>
```rust
  match epoch % 100 {
      0 => println!("Mean Loss (epoch {}) = {}", epoch, results[0].as_ref().unwrap()),    // Print training loss every 100 epochs
      _ => ()
  }
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Note that the index I'm using to select from `results` to get
the numeric value of `mean_loss` corresponds to the order which we pushed symbolic
tensors to the evaluator. Because I pushed `mean_loss` first, it takes index `0`. The
actual entry at that index is a `Result` type (which can be either an `Ok` value for the
numeric tensor value, or an `Err` error value), so I need to `unwrap()` it.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Now that we've coded up the training loop, the last thing there
is to do is handle behavior of this script after the training is complete. I'd like to
save the learned parameters to a file, which is luckily very easy with `autograd`:

<br>
```rust
  // --snip--
  env.save("results.json").unwrap();      // Save the learned parameters to a JSON file
  // --snip--
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; The very last thing I do before ending the script is print to
the command line what the learned parameters are after our last epoch, so we can
visually compare them to their "true" values we set for our synthetic dataset.

<br>
```rust
  // --snip--
  let ns = env.default_namespace();
  let finalw = &ns.get_array_by_name("w").unwrap().borrow();  // Borrow the learned weight value
  let finalb = &ns.get_array_by_name("b").unwrap().borrow();  // Borrow the learned bias value
  println!("Final w = {}", finalw);
  println!("Final b = {}", finalb);                           // Print them out
```

<br>
&nbsp;&nbsp;&nbsp;&nbsp; Once again, I make use of the environment's namespace, storing
it as `ns`. It is from this `Namespace` instance which I can borrow the latest evaluated values
assigned to each variable by calling the function `get_array_by_name()`, which also results
in a `Result`, so we must unwrap it. However, the `Result` itself wraps a `RefCell` object
(used often in multi-threaded applications), from which we can get the stored value via
the `borrow()` function.

<br>
&nbsp;&nbsp;&nbsp;&nbsp; And that's pretty much all there is to it! Using `cargo build`
gives us no compiler errors or warnings, and we can execute the resulting compiled
program to see the results we expected:

<br>
<img class="centered" alt="Cmd Line Results" src="/assets/images/autograd_linreg_output.PNG"/>

<br>
&nbsp;&nbsp;&nbsp;&nbsp; I'm satisfied with these results, because it's clear that the
error quickly converged within the first 700 or so epochs, and our learned parameters
are within 0.05 of their "true values."

### Where to go from here
I'd like to find more practical uses of the auto-differentiation utilities provided by
`autograd` in a more comprehensive machine learning project. I think the next application
I'll try to implement with this will be a custom Variational Autoencoder (VAE). Stay
tuned for blog updates to see how I get on with implementing this (admittedly, much
more complicated) model in the future.
