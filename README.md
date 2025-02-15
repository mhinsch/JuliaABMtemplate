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
- `run_cmdl.jl` ties everything together, creates model from commandline parameters and runs without gui

## Changing the model

In order to implement a new model only a few of the included files have to be changed:

- `model.jl` for the model itself
- `setup.jl` for model-specific setup and initialisation
- `params.jl` to define model parameters
- `analysis.jl` for output

And for the GUI version:

- `draw_gui.jl` to display the model
- `run_gui.jl` for model-specific graphs


## Remarks

Run as `julia run_gui.jl` or `julia run_cmdl.jl`. Run with `--help` to see commandline options.


`draw_vector.jl` contains currently unused code to draw the world as an SVG image using Luxor.


## Requirements

In order to run the model the following packages have to be installed:

- MiniEvents (not registered yet, for now install as `add https://github.com/mhinsch/MiniEvents.jl`)
- MiniObserve
- DataStructures
- Distributions
- ArgParse
- Parameters
- MacroTools
- StaticArrays
- SimpleDirectMediaLayer (for GUI only)

