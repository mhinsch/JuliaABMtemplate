using SSDL
using SimpleGraph
using SimpleGui


### draw GUI

# draw world to canvas
function draw_world(canvas, model)
	xs = canvas.xsize - 1
	ys = canvas.ysize - 1

	# draw connections
	for p in model.pop
		x1 = trunc(Int, p.x * xs) + 1
		y1 = trunc(Int, p.y * ys) + 1

		for p2 in p.contacts
			x2 = trunc(Int, p2.x * xs) + 1
			y2 = trunc(Int, p2.y * ys) + 1

			line(canvas, x1, y1, x2, y2, red(255))
		end
	end

	# draw agents
	for p in model.pop
		x = trunc(Int, p.x * xs) + 1
		y = trunc(Int, p.y * ys) + 1
		
		if p.status == infected
			col = red(255)
		elseif p.status == immune
			col = green(255)
		elseif p.status == susceptible
			col = blue(255)
		elseif p.status == dead
			col = rgb(120, 120, 120)
		end
		
		circle_fill(canvas, x, y, 3, UInt32(col), true)
	end
end

# draw both panels to video memory
function draw(model, graphs, gui)
	clear!(gui.canvas)
	draw_world(gui.canvas, model)
	update!(gui.panels[1,1], gui.canvas)

	clear!(gui.canvas)
	draw_graph(gui.canvas, graphs)
	update!(gui.panels[2, 1], gui.canvas)
end

