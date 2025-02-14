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

using SimpleDirectMediaLayer.LibSDL2
using SimpleGui

include("draw_gui.jl")



### run simulation with given setup and parameters

function run(sim, gui, graphs, t_stop, logfile, max_step = 1.0)
	model = sim.model
	t = 1.0
	step = max_step
	last = 0

	pause = false
	quit = false
	while ! quit
		# don't do anything if we are in pause mode
		if pause
			sleep(0.03)
			continue
		end

		t1 = time()
		step_until!(sim, t) # run internal scheduler up to the next time step
		
		# we want the analysis to happen at every integral time step
		if (now = trunc(Int, t)) >= last
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				data = observe(Data, model)
				# print all stats to file
				data = observe(Data, model, i)
				log_results(logfile, data)
				# we can just reuse the observation results
				add_value!(graphs[1], data.susceptible.n)
				add_value!(graphs[2], data.infected.n)
				add_value!(graphs[3], data.immune.n)
				add_value!(graphs[4], data.dead.n)
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

		println(t)

		# end simulation if requested number of steps has been run
		if t_stop > 0 && t >= t_stop
			break
		end
		
		event_ref = Ref{SDL_Event}()
        while Bool(SDL_PollEvent(event_ref))
            evt = event_ref[]
            evt_ty = evt.type
			if evt_ty == SDL_QUIT
                quit = true
                break
            elseif evt_ty == SDL_KEYDOWN
                scan_code = evt.key.keysym.scancode
                if scan_code == SDL_SCANCODE_ESCAPE || scan_code == SDL_SCANCODE_Q
					quit = true
					break
                elseif scan_code == SDL_SCANCODE_P || scan_code == SDL_SCANCODE_SPACE
					pause = !pause
                    break
                else
                    break
                end
            end
		end

		# draw gui to video memory
		draw(model, graphs, gui)
		# copy to screen
		render!(gui)
	end
end



### setup, run, cleanup



## parameters

# parse command line args
using ArgParse 
# translate params to args and vice versa
using Params2Args

const arg_settings = ArgParseSettings("run simulation", autofix_names=true)

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

const model = setup(p, args[:rand_seed])

const logf = prepare_outfiles("log_file.txt")

# two 640x640 panels next to each other
const gui = setup_Gui("SIRSm", 640, 640, 2, 1)
const graphs = [Graph{Int}(green(255)), Graph{Int}(red(255)), Graph{Int}(blue(255)), Graph{Int}(WHITE)] 



## run

init_events(model)
run(model, gui, graphs, args[:stop_time], logf, args[:max_step])



## cleanup

close(logf)

SDL2.Quit()
