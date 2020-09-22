module SimpleGui

export setup_window, Panel, update!, render!, Gui, setup_Gui, SDL2

using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 

# for the canvas
using SSDL


# create a window
function setup_window(wx, wy, title)
	SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLEBUFFERS, 16)
	SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLESAMPLES, 16)

	SDL2.init()

	win = SDL2.CreateWindow(title, Int32(0), Int32(0), Int32(wx), Int32(wy), 
		UInt32(SDL2.WINDOW_SHOWN))
	SDL2.SetWindowResizable(win,false)

	SDL2.CreateRenderer(win, Int32(-1), UInt32(SDL2.RENDERER_ACCELERATED))
end


# one panel + an associated texture matching the window format
struct Panel
	rect :: SDL2.Rect
	texture
	renderer
end

function Panel(renderer, sizex, sizey, offs_x, offs_y)
	Panel(
		SDL2.Rect(offs_x, offs_y, sizex, sizey),
		SDL2.CreateTexture(renderer, SDL2.PIXELFORMAT_ARGB8888, 
			Int32(SDL2.TEXTUREACCESS_STREAMING), Int32(sizex), Int32(sizey)),
		renderer
	)
end


# copy buffer to panel texture
function update!(p :: Panel, buf)
	SDL2.UpdateTexture(p.texture, C_NULL, buf, Int32(p.rect.w * 4))
end

# overload for canvas
update!(p :: Panel, c :: Canvas) = update!(p, c.pixels)

# draw texture on screen
function render!(p :: Panel)
	SDL2.RenderCopy(p.renderer, p.texture, C_NULL, pointer_from_objref(p.rect))
end


# everything put together
struct Gui
	panels :: Matrix{Panel}
	canvas :: Canvas
	canvas_bg :: Canvas
end


# setup the gui (incl. windows) and return a gui object
function setup_Gui(title, panel_w = 640, panel_h = 640, x=2, y=2)
	win_w = panel_w * x
	win_h = panel_h * y

	renderer = setup_window(win_w, win_h, title)

	canvas = Canvas(panel_w, panel_h)
	canvas_bg = Canvas(panel_w, panel_h)

	panels = Matrix{Panel}(undef, x, y)
	for i in 1:x, j in 1:y
		panels[i, j] = Panel(renderer, panel_w, panel_h, (i-1) * panel_w, (j-1) * panel_h)
	end

	Gui(panels, canvas, canvas_bg)
end


# draw all panels to the screen
function render!(gui)
	SDL2.RenderClear(gui.panels[1].renderer)
	for p in gui.panels
		render!(p)
	end
    SDL2.RenderPresent(gui.panels[1].renderer)
end


end
