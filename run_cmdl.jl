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



### run simulation with given setup and parameters


function run_events(sim, t_stop, logfile)
	model = sim.model
	t = 1.0
	step = 1.0
	last = 0

	while t_stop <= 0 || t < t_stop
		step_until!(sim, t) # run internal scheduler up to the next time step
		
		# we want the analysis to happen at every integral time step
		if (now = trunc(Int, t)) >= last
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				# print all stats to file
				data = observe(Data, model, now)
				log_results(logfile, data)
			end
			# remember when we did the last data output
			last = now
		end

		t += step

#		println(t)
	end
end


function run_steps(sim, t_stop, logfile, ord)
	model = sim.model
	for t in 1:t_stop
		update_model!(model, ord)
		# print all stats to file
		data = observe(Data, model, t)
		log_results(logfile, data)
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
	"--step-wise", "-s"
		help = "run the model step-wise instead of event-based"
		arg_type = Bool
		default = false
	"--shuffle"
		help = "if running step-wise shuffle the population"
		arg_type = Bool
		default = false
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



## run

if args[:step_wise]
	@time run_steps(sim, trunc(Int, args[:stop_time]), logf, args[:shuffle])
else
	init_events(sim)
	@time run_events(sim, args[:stop_time], logf)
end



## cleanup

close(logf)

