### include library code

using Random

using SimpleAgentEvents
using SimpleAgentEvents.Scheduler



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

mutable struct Model
    scheduler :: PQScheduler{Float64}
    inf :: Float64
    rec :: Float64
    imm :: Float64
    mort :: Float64
    
    pop :: Vector{Person}
end

scheduler(model :: Model) = model.scheduler

Model(i, r, u, m) = Model(PQScheduler{Float64}(), i, r, u, m, [])



### declare simulation processes

@processes SIRm model person::Person begin
    @poisson(model.inf * count(p -> p.status == infected, person.contacts)) ~
        person.status == susceptible        => 
            begin
                person.status = infected
                [person; person.contacts]
            end

    @poisson(model.rec)  ~
        person.status == infected           => 
            begin
                person.status = susceptible
                [person; person.contacts]
            end

    @poisson(model.imm)  ~
        person.status == infected           => 
            begin
                person.status = immune
                person.contacts
            end
    
    @poisson(model.mort)  ~
        person.status == infected           => 
            begin
                person.status = dead
                person.contacts
            end    
end



