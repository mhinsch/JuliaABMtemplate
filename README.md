# JuliaABMtemplate

A very simple standalone ABM example in Julia that can be used as a starting point for a new ABM implementation.

## Overview

All model-specific code is contained in lower-case .jl files. All other files contain modules that are more or less general and can be reused.

The main parts of the model:

- `setup_world.jl` functions to create the world in different configurations
- `model.jl` data structures and processes that make up the model itself
- `analysis.jl` observations and data output
- `setup.jl` create a runnable model
- `params.jl` model parameters
- `draw_gui.jl` draw the model to a canvas
- `run_gui.jl` ties everything together, creates model from commandline parameters and runs it with GUI

## Remarks


Currently only a version using an SDL-based GUI is implemented, but it should be relatively straightforward to implement
a commandline version by editing `run_gui.jl`.

`draw_vector.jl` contains currently unused code to draw the world as an SVG image using Luxor.


## Requirements

In order to run the model the following packages have to be installed:

DataStructures
Distributions
ArgParse
Parameters
MacroTools
StaticArrays
SimpleDirectMediaLayer
