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



push!(LOAD_PATH, "./src")

using SimpleAgentEvents


mutable struct A1
	id :: Int
	state :: Int
	food :: Int
end

mutable struct Model
	pop :: Vector{A1}
end

Model() = Model([])

struct Simulation
	model :: Model
end


function A1(i)
	A1(i, 0, 0)
end


function wakeup(a::A1, model)
#	println("$(a.id): wake up")
	a.state = 1

	[a]
end

function sleep(a::A1, model)
#	println("$(a.id): sleep")
	a.food -= 1

	[a]
end

function walk(a::A1, model)
#	println("$(a.id): walk")
	a.food -= 1

	[a]
end

function forage(a::A1, model)
#	println("$(a.id): forage")
	a.food += rand(1:5)

	[a]
end

function fallasleep(a::A1, model)
#	println("$(a.id): go to bed")
	a.state = 0

	[a]
end


const simulation = Simulation(Model())


@processes SimpleTest simulation self::A1 begin
	# wake up
	@poisson(2.0)	~ self.state == 0					=> wakeup(self, simulation.model)
	@poisson(1.0)	~ self.state == 0					=> sleep(self, simulation.model)
	@poisson(0.5)	~ self.state == 1 && self.food > 3	=> walk(self, simulation.model)
	@poisson(1.0) 	~ self.state == 1 && self.food <= 3	=> forage(self, simulation.model)
	@poisson(3.0)	~ self.state == 1 && self.food > 1	=> fallasleep(self, simulation.model)
end

@add_processes SimpleTest simulation m::Model begin
	@poisson(10.0) ~ length(m.pop) < 10 => begin
		push!(m.pop, A1(1))
		SimpleTest.spawn(m.pop[end], simulation)
		println("added agent")
		[m]
	end
end

function setup()
	SimpleTest.spawn(simulation.model, simulation)
end

function run(n)
	for i in 1:n
		SimpleTest.next!()
	end
	println(SimpleTest.time_next())
end

setup()

run(10)
