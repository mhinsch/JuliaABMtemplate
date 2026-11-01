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



module SimpleGui

export setup_window, Panel, update!, render!, Gui, setup_Gui, SDL2, redraw_at!, screenshot

using SimpleDirectMediaLayer.LibSDL2

# for the canvas
using SSDL


# create a window
function setup_window(wx, wy, title)
	SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
	SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)

	SDL_Init(SDL_INIT_EVERYTHING)

	win = SDL_CreateWindow(title, Int32(0), Int32(0), Int32(wx), Int32(wy), 
		UInt32(SDL_WINDOW_SHOWN))
	SDL_SetWindowResizable(win, SDL_FALSE)

	SDL_CreateRenderer(win, Int32(-1), UInt32(SDL_RENDERER_ACCELERATED)), win
end


# one panel + an associated texture matching the window format
struct Panel
	texture :: Ptr{SDL_Texture}
	rect :: Ref{SDL_Rect}
end

function Panel(texture, sizex, sizey, offs_x, offs_y)
	Panel(texture, Ref(SDL_Rect(offs_x, offs_y, sizex, sizey)))
end


# copy buffer to panel texture
function update!(p :: Panel, buf)
	SDL_UpdateTexture(p.texture, p.rect, buf, Int32(p.rect[].w * 4))
end

# overload for canvas
update!(p :: Panel, c :: Canvas) = update!(p, c.pixels)

# draw texture on screen
#function render!(p :: Panel)
#	SDL_RenderCopy(p.renderer, p.texture, C_NULL, pointer_from_objref(p.rect))
#end


# everything put together
struct Gui
	window :: Ptr{SDL_Window}
 	renderer :: Ptr{SDL_Renderer}
	texture :: Ptr{SDL_Texture}
	rect :: Ref{SDL_Rect}
	panels :: Vector{Panel}
	canvases :: Vector{Canvas}
end


# setup the gui (incl. windows) and return a gui object
function setup_Gui(title, width = 640, height = 640, panel_desc...)
	renderer, win = setup_window(width, height, title)
	texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
			Int32(SDL_TEXTUREACCESS_STREAMING), Int32(width), Int32(height))

	mx = maximum(p->last(p[1]), panel_desc)
	my = maximum(p->last(p[2]), panel_desc)

	xunit = width÷mx
	@assert width % mx == 0
	yunit = height÷my
	@assert height % my == 0
	
	panels = Panel[]
	canvases = Canvas[]
	
	for p in panel_desc
		x1 = first(p[1])
		x2 = last(p[1])
		y1 = first(p[2])
		y2 = last(p[2])

		panel_w = (x2-x1 + 1) * xunit
		@assert panel_w > 0
		
		panel_h = (y2-y1 + 1) * yunit
		@assert panel_h > 0

		panel = Panel(texture, panel_w, panel_h, (x1-1)*xunit, (y1-1)*yunit)
		canvas = Canvas(panel_w, panel_h)
		push!(panels, panel)
		push!(canvases, canvas)
	end

	Gui(win, renderer, texture, Ref(SDL_Rect(0, 0, width, height)), panels, canvases)
end


function redraw_at!(fn, gui, idx, col=0)
	clear!(gui.canvases[idx], col)
	fn(gui.canvases[idx])
	update!(gui.panels[idx], gui.canvases[idx])
	nothing
end


# draw all panels to the screen
function render!(gui)
	SDL_RenderClear(gui.renderer)
	SDL_RenderCopy(gui.renderer, gui.texture, C_NULL, pointer_from_objref(gui.rect))
	#for p in gui.panels
	#	render!(p)
	#end
    SDL_RenderPresent(gui.renderer)
end


function screenshot(gui, fname)
	screenshot = SDL_CreateRGBSurface(0, gui.rect[].w, gui.rect[].h, 32, 0, 0, 0, 0)

	println(typeof(screenshot))

	px = unsafe_load(screenshot).pixels
	pt = unsafe_load(screenshot).pitch
	println(typeof(px))
	println(typeof(pt))

	SDL_RenderClear(gui.renderer)
	SDL_RenderCopy(gui.renderer, gui.texture, C_NULL, pointer_from_objref(gui.rect))

	SDL_RenderReadPixels(gui.renderer, gui.rect, 0, px, pt)
	IMG_SaveJPG(screenshot, fname, 70)
end


end
