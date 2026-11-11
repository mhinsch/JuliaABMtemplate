#   Copyright (C) 2020 Martin Hinsch <hinsch.martin@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.



include("setup.jl")

using GLMakie

include("draw_gui_mk.jl")



### run simulation with given setup and parameters

function run_mk(sim, gui, t_stop, logfile, max_step = 1.0)
	model = sim.model
	t = 1.0
	step = max_step
	last = 0

	paused = Observable(false)
	stopped = Observable(false)

	# show the window and keep a handle for closing it later
	screen = display(gui.figure)

	on(events(gui.figure).keyboardbutton) do event
		event.action == Keyboard.press || return

		if event.key == Keyboard.escape || event.key == Keyboard.q
			stopped[] = true
		elseif event.key == Keyboard.p || event.key == Keyboard.space
			paused[] = !paused[]
		end
	end

	on(events(gui.figure).window_open) do open
		if !open
			stopped[] = true
		end
	end

	simulation = @async begin
		try
			while !stopped[]
				# don't do anything if we are in pause mode
				if paused[]
					sleep(0.03)
					continue
				end

				t1 = time()
				step_until!(sim, t) # run internal scheduler up to the next time step

				# we want the analysis to happen at every integral time step
				if (now = trunc(Int, t)) > last
					# in case we skipped a step (shouldn't happen, but just in case...)
					for i in (last+1):now
						data = observe(Data, model, i)
						log_results(logfile, data)
						update_graphs!(gui, i, data)
					end
					# remember when we did the last data output
					last = now
				end

				t += step

				# measure (real-world) time it took to simulate one step
				dt = time() - t1

				# adjust simulation step size
				if dt > 0.1
					step /= 1.1
				elseif dt < 0.03 && step < max_step # this is a simple model, so let's limit
					step *= 1.1                # max step size to about 1
				end

				# update the visible state of the model
				draw_mk(model, gui)

				# end simulation if requested number of steps has been run
				if t_stop > 0 && t >= t_stop
					break
				end

				# give the renderer and the event loop a chance to run
				sleep(0.001)
			end
		catch err
			@error "Simulation failed" exception = (err, catch_backtrace())
		finally
			stopped[] = true
			if isopen(screen)
				close(screen)
			end
		end
	end

	# block until the window is closed (either by the user or by the simulation)
	wait(screen)
	stopped[] = true
	wait(simulation)

	nothing
end



### setup, run, cleanup


## parameters

# parse command line args
using ArgParse
# translate params to args and vice versa
using Params2Args

const arg_settings = ArgParseSettings("run simulation with GLMakie", autofix_names=true)

@add_arg_table! arg_settings begin
	"--rand-seed", "-r"
		help = "random seed"
		arg_type = Int
		default = 42
	"--stop-time", "-t"
		help = "at which time to stop the simulation"
		arg_type = Float64
		default = 0.0
	"--max-step", "-m"
		help = "upper limit for simulated time per frame"
		arg_type = Float64
		default = 1.0
end

# new group of arguments
add_arg_group!(arg_settings, "simulation parameters")

# translate Params into args
include("params.jl")
fields_as_args!(arg_settings, Params)

# parse cmdl args
const args = parse_args(arg_settings, as_symbols=true)
# and create a Params object from them
const p = @create_from_args(args, Params)



## setup

const sim = setup(p, args[:rand_seed])

const logf = prepare_outfiles("log_file.txt")

const gui = setup_gui_mk(sim.model)



## run

init_events(sim)
run_mk(sim, gui, args[:stop_time], logf, args[:max_step])



## cleanup

close(logf)
