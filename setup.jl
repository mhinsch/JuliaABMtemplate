### include all the other pieces of code

push!(LOAD_PATH, pwd()) # let Julia find local packages

include("model.jl")
include("setup_world.jl")
include("analysis.jl")



### prepare the simulation

# this function prepares running the simulation on a grid world
function setup_model_grid(inf, rec, imm, mort, x, y, seed)
    
    model = Model(inf, rec, imm, mort)
    model.pop = setup_grid(x, y)
    model.pop[1].status = infected

    for person in model.pop
        spawn_SIRm(person, model)
    end

    Random.seed!(seed)

	model
end
    
# prepare running the simulation on a random geometric graph
# the number of connections and with it runtime is very sensitive to near
function setup_model_geograph(inf, rec, imm, mort, N, near, nc, seed)
    model = Model(inf, rec, imm, mort)
    model.pop = setup_geograph(N, near, nc)
    model.pop[1].status = infected

    for person in model.pop
        spawn_SIRm(person, model)
    end

    Random.seed!(seed)

	model
end

function prepare_outfiles(fname)
	logfile = open(fname, "w")
	print_header_stat_log(logfile)
	logfile
end

