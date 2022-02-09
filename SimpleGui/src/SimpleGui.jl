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

export setup_window, Panel, update!, render!, Gui, setup_Gui, SDL2

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

	SDL_CreateRenderer(win, Int32(-1), UInt32(SDL_RENDERER_ACCELERATED))
end


# one panel + an associated texture matching the window format
struct Panel
	rect :: Ref{SDL_Rect}
	texture
	renderer
end

function Panel(renderer, sizex, sizey, offs_x, offs_y)
	Panel(
		Ref(SDL_Rect(offs_x, offs_y, sizex, sizey)),
		SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, 
			Int32(SDL_TEXTUREACCESS_STREAMING), Int32(sizex), Int32(sizey)),
		renderer
	)
end


# copy buffer to panel texture
function update!(p :: Panel, buf)
	SDL_UpdateTexture(p.texture, C_NULL, buf, Int32(p.rect[].w * 4))
end

# overload for canvas
update!(p :: Panel, c :: Canvas) = update!(p, c.pixels)

# draw texture on screen
function render!(p :: Panel)
	SDL_RenderCopy(p.renderer, p.texture, C_NULL, pointer_from_objref(p.rect))
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
	SDL_RenderClear(gui.panels[1].renderer)
	for p in gui.panels
		render!(p)
	end
    SDL_RenderPresent(gui.panels[1].renderer)
end


end
