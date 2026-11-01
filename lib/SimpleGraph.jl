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

using Cairo
using Printf

export Graph, add_value!, draw_graph, set_data!

using SSDL

### super simplistic graph implementation

mutable struct Graph{T}
	data :: Vector{T}
	max :: T
	min :: T
	keys :: Vector{Float64}
	xmax :: Float64
	xmin :: Float64
	colour :: UInt32
	label :: String
	method :: Symbol
	size :: Int
end

Graph{T}(col, lab; method=:line, size=2) where {T} =
	Graph{T}([], typemin(T), typemax(T),
		[], -Inf, Inf,
		col, lab, method, size)

key(graph, idx) = isempty(graph.keys) ? idx : graph.keys[idx]

x_max(graph) = isempty(graph.keys) || graph.xmax == -Inf || isnan(graph.xmax) ?
	length(graph.data) : graph.xmax
x_min(graph) = isempty(graph.keys) || graph.xmin == Inf || isnan(graph.xmin) ?
	1 : graph.xmin

function add_value!(graph::Graph, value)
	if isnan(value) || isinf(value)
		value = zero(value)
	end
	
	push!(graph.data, value)
	
	graph.max = max(graph.max, value)
	graph.min = min(graph.min, value)
end

function add_value!(graph::Graph, value, key::Float64)
	add_value!(graph, value)
	push!(graph.keys, key)
	graph.xmax = max(graph.xmax, key)
	graph.xmin = min(graph.xmin, key)
	@assert length(graph.keys) == length(graph.data)
	nothing
end


function set_data!(graph::Graph, data; maxm = data[1], minm = data[1])
    graph.data = data
    graph.max = maxm == data[1] ? maximum(data) : maxm
    graph.min = minm == data[1] ? minimum(data) : minm
end

function set_data!(graph::Graph, keys::Vector{Float64}, data;
		maxm = data[1], minm = data[1],
		xmaxm = -Inf, xminm = Inf)
	set_data!(graph, data; maxm, minm)
	@assert length(keys) == length(graph.data)
	graph.keys = keys
    graph.xmax = xmaxm == -Inf ? maximum(keys) : xmaxm
    graph.xmin = xminm == Inf ? minimum(keys) : xminm
	nothing
end


function draw_legend(cr, x, y, value, colour)
	move_to(cr, x, y)
	set_source_rgb(cr, argb_tuple(colour)[2:4]...)
    text = @sprintf "%.4f" value
	show_text(cr, text)
	nothing
end


x_coord(graph, mi, scale, idx) = trunc(Int, (key(graph, idx) - mi) * scale) 
y_coord(graph, mi, scale, idx) = trunc(Int, (graph.data[idx] - mi) * scale) 


# draw graph to canvas
function draw_graph(canvas, graphs, single_y_scale=true, single_x_scale=false)
	if single_y_scale # draw all graphs to the same scale
		max_all = mapreduce(g -> g.max, max, graphs) # find maximum of graphs[...].max
		min_all = mapreduce(g -> g.min, min, graphs)
	end

	if single_x_scale
		xmax_all = mapreduce(g -> x_max(g), max, graphs) # find maximum of graphs[...].xmax
		xmin_all = mapreduce(g -> x_min(g), min, graphs)
	end

	fontsize = 18.0

	surf = CairoImageSurface(reshape(canvas.pixels, canvas.xsize, canvas.ysize), Cairo.FORMAT_ARGB32, flipxy=false)
	cr = CairoContext(surf)
	select_font_face(cr, "sans", Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
	set_font_size(cr, fontsize)
	
    width_legend = round(Int, text_extents(cr, "WWWWW")[3])
    width_g = canvas.xsize-1 - width_legend 
    height_g = canvas.ysize-1 - round(Int, fontsize)
    x_0_g = width_legend

    #println(width_legend, " ", width_g, " ", height_g, " ", x_0_g)

	for g in graphs
		g_min, g_max = single_y_scale ? (min_all, max_all) : (g.min, g.max)
		g_x_min, g_x_max = single_x_scale ? (xmin_all, xmax_all) : (x_min(g), x_max(g))

		# no x or y range, can't draw
		if g_max <= g_min || g_x_max <= g_x_min
			continue
		end

		x_scale = width_g / (g_x_max - g_x_min)
		y_scale = height_g / (g_max - g_min)
		
		if g.method== :line
			dxold = x_0_g + x_coord(g, g_x_min, x_scale, 1) + 1
			dyold = height_g - y_coord(g, g_min, y_scale, 1) + 1

			for i in 2:length(g.data)
				dx = x_0_g + x_coord(g, g_x_min, x_scale, i) + 1
				dy = height_g - y_coord(g, g_min, y_scale, i) + 1
				line(canvas, dxold, dyold, dx, dy, g.colour)
				dxold, dyold = dx, dy
			end
		elseif g.method == :scatter
			for i in 1:length(g.data)
				dx = x_0_g + x_coord(g, g_x_min, x_scale, i) + 1
				dy = height_g - y_coord(g, g_min, y_scale, i) + 1
				SSDL.circle_fill(canvas, dx, dy, g.size, g.colour, true)
			end
		end
	end

    if single_y_scale
        draw_legend(cr, 0, height_g, min_all, graphs[1].colour)
        draw_legend(cr, 0, fontsize, max_all, graphs[1].colour)
    else
        yoffs = 0 + height_g - fontsize * length(graphs)
        for (i, g) in enumerate(graphs)
            draw_legend(cr, 0, yoffs + (i-1) * fontsize, g.min, g.colour)
            draw_legend(cr, 0, (i-1) * fontsize, g.max, g.colour)
        end
    end

    w = 0
    for g in graphs
        w = max(w, text_extents(cr, g.label*"W")[3])
    end

    lx = canvas.xsize - w

    for (i, g) in enumerate(graphs)
    	move_to(cr, lx, i * fontsize)
		set_source_rgb(cr, argb_tuple(g.colour)[2:4]...)
        show_text(cr, g.label)
    end
end


end
