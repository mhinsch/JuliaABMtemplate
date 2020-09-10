### include library code


using Random
using DataFrames
using Gadfly

include("SimpleAgentEvents/src/SimpleAgentEvents.jl")

using .SimpleAgentEvents
using .SimpleAgentEvents.Scheduler



### declare agent type(s)

@enum Status susceptible infected immune dead

mutable struct Person
    status :: Status
    contacts :: Vector{Person}
    x :: Float64
    y :: Float64
end

Person(x, y) = Person(susceptible, [], x, y)
Person(state, x, y) = Person(state, [], x, y)



### declare simulation

mutable struct Simulation
    scheduler :: PQScheduler{Float64}
    inf :: Float64
    rec :: Float64
    imm :: Float64
    mort :: Float64
    
    pop :: Vector{Person}
end

scheduler(sim :: Simulation) = sim.scheduler

Simulation(i, r, u, m) = Simulation(PQScheduler{Float64}(), i, r, u, m, [])



### declare simulation processes

@processes SIRm sim person::Person begin
    @poisson(sim.inf * count(p -> p.status == infected, person.contacts)) ~
        person.status == susceptible        => 
            begin
                person.status = infected
                [person; person.contacts]
            end

    @poisson(sim.rec)  ~
        person.status == infected           => 
            begin
                person.status = susceptible
                [person; person.contacts]
            end

    @poisson(sim.imm)  ~
        person.status == infected           => 
            begin
                person.status = immune
                person.contacts
            end
    
    @poisson(sim.mort)  ~
        person.status == infected           => 
            begin
                person.status = dead
                person.contacts
            end    
end



### run the simulation

include("setup_world.jl")
include("draw.jl")

# this function runs the simulation on a grid world
function run_grid(inf, rec, imm, mort, x, y, tim, seed)
    # this part hasn't changed
    
    sim = Simulation(inf, rec, imm, mort)
    sim.pop = setup_grid(x, y)
    sim.pop[1].status = infected

    for person in sim.pop
        spawn_SIRm(person, sim)
    end

    Random.seed!(seed)
    
    # we create a few arrays to put the data in
    n_inf = Int[]
    n_susc = Int[]
    n_imm = Int[]
    n_dead = Int[]

    
    for t in  1:tim
        # run a time step
        upto!(sim.scheduler, time_now(sim.scheduler) + 1.0)
        
        # then count agents in all states and store the numbers in the arrays
        push!(n_inf, count(p -> p.status == infected, sim.pop))
        push!(n_susc, count(p -> p.status == susceptible, sim.pop))
        push!(n_imm, count(p -> p.status == immune, sim.pop))
        push!(n_dead, count(p -> p.status == dead, sim.pop))
    end
    
    # we bundle up the arrays in a DataFrame for easier handling
    DataFrame(inf = n_inf, susc = n_susc, imm = n_imm, dead = n_dead), sim
end


# run the simulation on a random geometric graph
# *set near < 0.05!* (otherwise there will be MANY connections and
# the visualisation might crash your browser)
function run_geograph(inf, rec, imm, mort, N, near, nc, tim, seed)
    sim = Simulation(inf, rec, imm, mort)
    sim.pop = setup_geograph(N, near, nc)
    sim.pop[1].status = infected

    for person in sim.pop
        spawn_SIRm(person, sim)
    end

    Random.seed!(seed)
    
    n_inf = Int[]
    n_susc = Int[]
    n_imm = Int[]
    n_dead = Int[]

    
    for t in  1:tim
        upto!(sim.scheduler, time_now(sim.scheduler) + 1.0)
        push!(n_inf, count(p -> p.status == infected, sim.pop))
        push!(n_susc, count(p -> p.status == susceptible, sim.pop))
        push!(n_imm, count(p -> p.status == immune, sim.pop))
        push!(n_dead, count(p -> p.status == dead, sim.pop))
    end
    
    DataFrame(inf = n_inf, susc = n_susc, imm = n_imm, dead = n_dead), sim
end



par_data = DataFrame(par_inf = Float64[], par_mort = Float64[], 
    n_inf = Int[], n_susc = Int[], n_imm = Int[], n_dead = Int[])

for inf in 0.1:0.2:2.0
    for mort in 0.1:0.2:2.0
        d, sim = run_grid(inf, 0.1, 0.2, mort, 50, 50, 100, 42)
        # get the last row
        d_last = last(d)
        push!(par_data, Float64[inf, mort, d_last[:inf], d_last[:susc], d_last[:imm], d_last[:dead]])
    end
end



par_data = DataFrame(par_inf = Float64[], par_mort = Float64[], 
    n_inf = Int[], n_susc = Int[], n_imm = Int[], n_dead = Int[])

for inf in 0.1:0.2:2.0
    for mort in 0.1:0.2:2.0
        d, sim = run_geograph(inf, 0.1, 0.2, mort, 2500, 0.03, 100, 100, 42)
        # get the last row
        d_last = last(d)
        # add last row and parameters to the data frame
        push!(par_data, Float64[inf, mort, d_last[:inf], d_last[:susc], d_last[:imm], d_last[:dead]])
    end
end

