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



### include all the other pieces of code

push!(LOAD_PATH, pwd()) # let Julia find local packages

include("model.jl")
include("setup_world.jl")
include("analysis.jl")



### prepare the simulation

function init_events(model)
    for person in model.pop
        SIRm.spawn(person, model)
    end
end

# this function prepares running the simulation on a grid world
function setup_model_grid(inf, rec, imm, mort, x, y, seed)
    
    model = Model(inf, rec, imm, mort)
    model.pop = setup_grid(x, y)
    model.pop[1].status = infected

    Random.seed!(seed)

	model
end
    
# prepare running the simulation on a random geometric graph
# the number of connections and with it runtime is very sensitive to near
function setup_model_geograph(inf, rec, imm, mort, N, near, nc, seed)
    model = Model(inf, rec, imm, mort)
    model.pop = setup_geograph(N, near, nc)
    model.pop[1].status = infected

    Random.seed!(seed)

	model
end

function prepare_outfiles(fname)
	logfile = open(fname, "w")
	print_header_stat_log(logfile)
	logfile
end

