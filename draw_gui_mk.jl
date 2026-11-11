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



using GLMakie


### colours

const GUI_BG = RGBf(100/255, 100/255, 100/255)

const COLOUR_SUSCEPTIBLE = RGBf(0.15, 0.35, 1.0)
const COLOUR_INFECTED    = RGBf(1.0, 0.15, 0.15)
const COLOUR_IMMUNE      = RGBf(0.15, 0.80, 0.25)
const COLOUR_DEAD        = RGBf(120/255, 120/255, 120/255)
const COLOUR_CONTACT     = RGBf(1.0, 0.15, 0.15)


### data kept by the graphs

mutable struct GraphData
	times       :: Vector{Float64}
	susceptible :: Vector{Float64}
	infected    :: Vector{Float64}
	immune      :: Vector{Float64}
	dead        :: Vector{Float64}
end

GraphData() = GraphData(Float64[], Float64[], Float64[], Float64[], Float64[])


### everything the GUI needs to update the plot

mutable struct MakieGui
	figure          :: Figure
	world_axis      :: Axis
	graph_axis      :: Axis
	agent_colours   :: Observable{Vector{RGBf}}
	graph_data      :: GraphData
	graph_times     :: Observable{Vector{Float64}}
	graph_susceptible :: Observable{Vector{Float64}}
	graph_infected  :: Observable{Vector{Float64}}
	graph_immune    :: Observable{Vector{Float64}}
	graph_dead      :: Observable{Vector{Float64}}
end


### helpers

function status_colour(status)
	if status == infected
		COLOUR_INFECTED
	elseif status == immune
		COLOUR_IMMUNE
	elseif status == susceptible
		COLOUR_SUSCEPTIBLE
	elseif status == dead
		COLOUR_DEAD
	else
		RGBf(1.0, 1.0, 1.0)
	end
end

status_colour(p::Person) = status_colour(p.status)

agent_colours(model) = RGBf[status_colour(p) for p in model.pop]


"Build one line segment for every contact. The model stores contacts in both directions."
function contact_segments(model)
	segments = Tuple{Point2f, Point2f}[]

	for p in model.pop
		p1 = Point2f(p.x, p.y)
		for p2 in p.contacts
			push!(segments, (p1, Point2f(p2.x, p2.y)))
		end
	end

	segments
end


### setup the GUI

function setup_gui_mk(model; width = 2000, height = 1000)
	fig = Figure(size = (width, height), backgroundcolor = GUI_BG)

	# world panel
	world_axis = Axis(fig[1, 1];
		aspect = DataAspect(),
		backgroundcolor = GUI_BG,
		limits = (-0.02, 1.02, -0.02, 1.02))
	hidedecorations!(world_axis)
	hidespines!(world_axis)

	# draw connections first, so agents are drawn on top of them
	linesegments!(world_axis, contact_segments(model);
		color = COLOUR_CONTACT,
		linewidth = 0.5)

	# agents
	positions = Point2f[Point2f(p.x, p.y) for p in model.pop]
	colours = Observable(agent_colours(model))
	scatter!(world_axis, positions;
		color = colours,
		marker = :circle,
		markersize = 8,
		strokewidth = 0)

	# graph panel
	graph_axis = Axis(fig[1, 2];
		title = "Population",
		xlabel = "time",
		ylabel = "agents",
		backgroundcolor = RGBf(1.0, 1.0, 1.0))

	graph_data = GraphData()
	graph_times = Observable(graph_data.times)
	graph_susceptible = Observable(graph_data.susceptible)
	graph_infected = Observable(graph_data.infected)
	graph_immune = Observable(graph_data.immune)
	graph_dead = Observable(graph_data.dead)

	lines!(graph_axis, graph_times, graph_susceptible;
		color = COLOUR_SUSCEPTIBLE, linewidth = 2, label = "susceptible")
	lines!(graph_axis, graph_times, graph_infected;
		color = COLOUR_INFECTED, linewidth = 2, label = "infected")
	lines!(graph_axis, graph_times, graph_immune;
		color = COLOUR_IMMUNE, linewidth = 2, label = "immune")
	lines!(graph_axis, graph_times, graph_dead;
		color = COLOUR_DEAD, linewidth = 2, label = "dead")

	axislegend(graph_axis; position = :rt, nbanks = 2)

	xlims!(graph_axis, 0.0, 10.0)
	ylims!(graph_axis, 0.0, 1.0)

	# make the world panel square and let the graph use the remaining space
	colsize!(fig.layout, 1, Aspect(1, 1))
	colsize!(fig.layout, 2, Relative(1))
	rowsize!(fig.layout, 1, Relative(1))

	Label(fig[2, 1:2], "Space/P: pause   Q/Esc: quit";
		fontsize = 14, color = RGBf(1.0, 1.0, 1.0), tellwidth = false)

	MakieGui(fig, world_axis, graph_axis, colours, graph_data,
		graph_times, graph_susceptible, graph_infected, graph_immune, graph_dead)
end


### update the GUI

function update_world!(gui::MakieGui, model)
	gui.agent_colours[] = agent_colours(model)
	nothing
end


function update_graphs!(gui::MakieGui, t, data)
	gd = gui.graph_data

	push!(gd.times, Float64(t))
	push!(gd.susceptible, Float64(data.n_susceptible.n))
	push!(gd.infected, Float64(data.n_infected.n))
	push!(gd.immune, Float64(data.n_immune.n))
	push!(gd.dead, Float64(data.n_dead.n))

	notify(gui.graph_times)

	autolimits!(gui.graph_axis)

	nothing
end


"Redraw the parts of the GUI that change while the simulation is running."
function draw_mk(model, gui::MakieGui)
	update_world!(gui, model)
	nothing
end
