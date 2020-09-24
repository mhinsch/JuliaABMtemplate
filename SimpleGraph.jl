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



module SimpleGraph

export Graph, add_value!, draw_graph

using SSDL

### super simplistic graph implementation

mutable struct Graph{T}
	data :: Vector{T}
	max :: T
	min :: T
	colour :: UInt32
end

Graph{T}(col) where {T} = Graph{T}([], typemin(T), typemax(T), col)

function add_value!(graph::Graph, value)
	push!(graph.data, value)
	value > graph.max ? (graph.max = value) : (value < graph.min ? (graph.min = value) : value)
end


# draw graph to canvas
function draw_graph(canvas, graphs, single_scale=true)
	if single_scale # draw all graphs to the same scale
		max_all = mapreduce(g -> g.max, max, graphs) # find maximum of graphs[...].max
		min_all = mapreduce(g -> g.min, min, graphs)
	end

	for g in graphs
		g_max = single_scale ? max_all : g.max
		g_min = single_scale ? min_all : g.min

		# no x or y range, can't draw
		if g_max <= g_min || length(g.data) <= 1
			continue
		end

		x_scale = (canvas.xsize-1) / (length(g.data)-1)
		y_scale = (canvas.ysize-1) / (g_max - g_min)
		
		dxold = 1
		dyold = canvas.ysize - trunc(Int, (g.data[1]-g_min) * y_scale ) 

		for i in eachindex(g.data)
			dx = trunc(Int, (i-1) * x_scale) + 1
			dy = canvas.ysize - trunc(Int, (g.data[i]-g_min) * y_scale) 
			line(canvas, dxold, dyold, dx, dy, g.colour)
			dxold, dyold = dx, dy
		end
	end
end


end
