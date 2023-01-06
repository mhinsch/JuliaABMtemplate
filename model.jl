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

using MiniEvents


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



### event-based: declare simulation processes

@events person::Person begin
	@debug
    @rate(@sim().model.inf * count(p -> p.status == infected, person.contacts)) ~
        person.status == susceptible        => 
            begin
#				println(model.inf * count(p -> p.status == infected, person.contacts))
                person.status = infected
                @r person person.contacts
            end

    @rate(@sim().model.rec)  ~
        person.status == infected           => 
            begin
                person.status = susceptible
                @r person person.contacts
            end

    @rate(@sim().model.imm)  ~
        person.status == infected           => 
            begin
                person.status = immune
                @r person person.contacts
            end
    
    @rate(@sim().model.mort)  ~
        person.status == infected           => 
            begin
                person.status = dead
                @r person person.contacts
            end    
end


@simulation SIRm Person begin
	model :: Model
end


function init_events(sim)
    for person in sim.model.pop
        spawn!(person, sim)
    end
end


### step-wise: define update functions

function update_agent!(a, model)
	if a.status == susceptible
		for c in a.contacts
			if c.status == infected && rand() < model.inf
				a.status = infected
				return
			end
		end
	
	elseif a.status == infected
		p_nochange = (1.0 - model.rec) * (1.0 - model.imm) * (1.0 - model.mort)
		p_change = 1.0 - p_nochange
		f = p_change / (model.rec + model.imm + model.mort)
		t_rec = p_nochange + model.rec * f
		t_imm = t_rec + model.imm * f

		r = rand()

		if r < p_nochange # nothing happens
		elseif r < t_rec
			a.status = susceptible
		elseif r < t_imm
			a.status = immune
		else
			a.status = dead
		end
	end
end


function update_model!(model, rand_order = true)
	order = rand_order ? shuffle(model.pop) : model.pop

	for a in order
		update_agent!(a, model)
	end
end
