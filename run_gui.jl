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

using SimpleGui

include("draw_gui.jl")



### run simulation with given setup and parameters

function run(model, gui, graphs, t_stop, logfile)
	t = 1.0
	step = 1.0
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
		SIRm.upto!(t) # run internal scheduler up to the next time step
		
		# we want the analysis to happen at every integral time step
		if (now = trunc(Int, t)) >= last
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				# print all stats to file
				print_stats_stat_log(logfile, model)
				# this is suboptimal, as all these are calculated in print_stats as well
				# solution forthcoming
				add_value!(graphs[1], count(ag -> ag.status == susceptible, model.pop))
				add_value!(graphs[2], count(ag -> ag.status == infected, model.pop))
				add_value!(graphs[3], count(ag -> ag.status == immune, model.pop))
				add_value!(graphs[4], count(ag -> ag.status == dead, model.pop))
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
		elseif dt < 0.03 && step < 1.0 # this is a simple model, so let's limit
			step *= 1.1                # max step size to about 1
		end

		println(t)

		# end simulation if requested number of steps has been run
		if t_stop > 0 && t >= t_stop
			break
		end
		
		# check for user input
		while (ev = SDL2.event()) != nothing
			if typeof(ev) <: SDL2.KeyboardEvent 
				if ev._type == SDL2.KEYDOWN
					key = ev.keysym.sym
					if key == SDL2.SDLK_ESCAPE || key == SDL2.SDLK_q
						quit = true
						break;
					elseif key == SDL2.SDLK_p || key == SDL2.SDLK_SPACE
						pause = ! pause
					end
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

const t_stop = args[:stop_time] 
const seed = args[:rand_seed]

const model = p.topology == 1 ?
	setup_model_grid(p.r_inf, p.r_rec, p.r_imm, p.r_mort, p.x, p.y, seed) :
	setup_model_geograph(p.r_inf, p.r_rec, p.r_imm, p.r_mort, p.N, p.near, p.nc, seed)

const logf = prepare_outfiles("log_file.txt")

# two 640x640 panels next to each other
const gui = setup_Gui("SIRSm", 640, 640, 2, 1)
const graphs = [Graph{Int}(green(255)), Graph{Int}(red(255)), Graph{Int}(blue(255)), Graph{Int}(WHITE)] 



## run

run(model, gui, graphs, t_stop, logf)



## cleanup

close(logf)

SDL2.Quit()
