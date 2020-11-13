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
    inf :: Float64
    rec :: Float64
    imm :: Float64
    mort :: Float64
    
    pop :: Vector{Person}
end

Model(i, r, u, m) = Model(i, r, u, m, [])



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



