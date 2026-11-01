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



module SSDL

export Canvas, xsize, ysize, clear!, put, put_clip,line, fillRectC, linePat,
	alpha, red, green, blue, rgb, argb, WHITE, argb_tuple,
	bresenham, bresenham_circle, circle, circle_fill

uint(f) = floor(UInt32, f)

struct Canvas
	pixels :: Vector{UInt32}
	xsize :: Int
	ysize :: Int
end

Canvas(xs :: Int, ys :: Int) = Canvas(Vector{UInt32}(undef, xs*ys), xs, ys)

# 1-based indexing
function put(canvas::Canvas, x::Int, y::Int, colour::UInt32)
	canvas.pixels[(y-1)*canvas.xsize + x] = colour
end


function put_clip(canvas::Canvas, x::Int, y::Int, colour::UInt32)
	if x<1 || y<1 || x>canvas.xsize || y>canvas.ysize
		return
	end

	put(canvas, x, y, colour)
end

function fillRectC(canvas::Canvas, x::Int, y::Int, w::Int, h::Int, colour::UInt32)
	xs, ys = size(canvas)

	xmi = max(1, x)
	xma = min(xs, x+w-1)
	ymi = max(1, y)
	yma = min(ys, y+h-1)

	for xx in xmi:xma
		for yy in ymi:yma
			put(canvas, xx, yy, colour)
		end
	end
end

function line(canvas::Canvas, x1::Int, y1::Int, x2::Int, y2::Int, col::UInt32)
	bresenham(x1, y1, x2, y2) do x, y
		put(canvas, x, y, col)
	end
end

function linePat(canvas::Canvas, x1::Int, y1::Int, x2::Int, y2::Int, on, off, col::UInt32)
	count = 1
	bresenham(x1, y1, x2, y2) do x, y
		if count <= on
			put(canvas, x, y, col)
		else
			count = count % (on+off) 
		end
		count += 1
	end
end

function circle(canvas::Canvas, x::Int, y::Int, r::Int, col::UInt32, clip = false)
	bresenham_circle(x, y, r, false, clip, 1, 1, canvas.xsize, canvas.ysize) do x, y
		put(canvas, x, y, col)
	end
end

function circle_fill(canvas::Canvas, x::Int, y::Int, r::Int, col::UInt32, clip = false)
	bresenham_circle(x, y, r, true, clip, 1, 1, canvas.xsize, canvas.ysize) do x, y
		put(canvas, x, y, col)
	end
end

xsize(canvas::Canvas) = canvas.xsize
ysize(canvas::Canvas) = canvas.ysize
Base.size(canvas::Canvas) = xsize(canvas), ysize(canvas)


clear!(canvas::Canvas, col=0) = fill!(canvas.pixels, col)


Base.copyto!(c1::Canvas, c2::Canvas) = copyto!(c1.pixels, c2.pixels)


alpha(x) = UInt32(x<<24)
alpha(x::F) where {F<:AbstractFloat} = alpha(floor(UInt32, x))

red(x) = UInt32(x<<16)
red(x::F) where {F<:AbstractFloat} = red(floor(UInt32, x))

green(x) = Int32(x<<8)
green(x::F) where {F<:AbstractFloat}  = green(floor(UInt32, x))

blue(x) = UInt32(x)
blue(x::F) where {F<:AbstractFloat}  = blue(floor(UInt32, x))

rgb(r, g, b) = red(r) | green(g) | blue(b)
argb(a, r, g, b) = alpha(a) | red(r) | green(g) | blue(b)

argb_tuple(c::UInt32) = (c .>> (24, 16, 8, 0) .& 0x000000FF) ./ 255

const WHITE = 0xFFFFFFFF

# based on this code:
# https://stackoverflow.com/questions/40273880/draw-a-line-between-two-pixels-on-a-grayscale-image-in-julia
function bresenham(f :: Function, x1::Int, y1::Int, x2::Int, y2::Int)
	#println("b: ", x1, ", ", y1)
	#println("b: ", x2, ", ", y2)
	# Calculate distances
	dx = x2 - x1
	dy = y2 - y1

	# Determine how steep the line is
	is_steep = abs(dy) > abs(dx)

	# Rotate line
	if is_steep == true
		x1, y1 = y1, x1
		x2, y2 = y2, x2
	end

	# Swap start and end points if necessary 
	if x1 > x2
		x1, x2 = x2, x1
		y1, y2 = y2, y1
	end
	# Recalculate differentials
	dx = x2 - x1
	dy = y2 - y1

	# Calculate error
	error = round(Int, dx/2.0)

	if y1 < y2
		ystep = 1
	else
		ystep = -1
	end

	# Iterate over bounding box generating points between start and end
	y = y1
	for x in x1:x2
		if is_steep == true
			coord = (y, x)
		else
			coord = (x, y)
		end

		f(coord[1], coord[2])

		error -= abs(dy)

		if error < 0
			y += ystep
			error += dx
		end
	end

end


function bresenham_circle_apply(f, xc, yc, x, y)
	xlims = (-x, x); ylims = (-y, y)

	for dx in xlims, dy in ylims
		f(xc+dx, yc+dy)
	end
	
	for dx in ylims, dy in xlims
		f(xc+dx, yc+dy)
	end
end

function bresenham_circle_clip_apply(f, xc, yc, x, y, clipx1, clipy1, clipx2, clipy2)
	for dy in (yc-y, yc+y)
		clipy1 <= dy <= clipy2 || continue
		
		if clipx1 <= xc-x <= clipx2
			f(xc-x, dy)
		end
		if clipx1 <= xc+x <= clipx2
			f(xc+x, dy)
		end
	end

	for dy in (yc-x, yc+x)
		clipy1 <= dy <= clipy2 || continue
		
		if clipx1 <= xc-y <= clipx2
			f(xc-y, dy)
		end
		if clipx1 <= xc+y <= clipx2
			f(xc+y, dy)
		end
	end
end

function bresenham_circle_fill_apply(f, xc, yc, x, y)
	for xx in xc-x:xc+x
		f(xx, yc-y)
		f(xx, yc+y)
	end
	for xx in xc-y:xc+y
		f(xx, yc-x)
		f(xx, yc+x)
	end
end

function bresenham_circle_fill_clip_apply(f, xc, yc, x, y, clipx1, clipy1, clipx2, clipy2)
	minx = max(xc-x, clipx1)
	maxx = min(xc+x, clipx2)
	if clipy1 <= yc-y <= clipy2
		for xx in minx:maxx
			f(xx, yc-y)
		end
	end
	if clipy1 <= yc+y <= clipy2
		for xx in minx:maxx
			f(xx, yc+y)
		end
	end

	minx = max(xc-y, clipx1)
	maxx = min(xc+y, clipx2)
	if clipy1 <= yc-x <= clipy2
		for xx in minx:maxx
			f(xx, yc-x)
		end
	end
	if clipy1 <= yc+x <= clipy2
		for xx in minx:maxx
			f(xx, yc+x)
		end
	end
end

function bresenham_circle(f::Function, xc::Int, yc::Int, r::Int, filled = false, 
	clip = false, x1=0, y1=0, x2=0, y2=0)
 
	# don't use costly clip if circle is within bounds
	if clip && 
		x1 <= xc-r <= xc+r <= x2 &&
		y1 <= yc-r <= yc+r <= y2
		clip = false
	end

	x = 0
	y = r 
	d = 3 - 2 * r 

	if filled
		if clip
			bresenham_circle_fill_clip_apply(f, xc, yc, x, y, x1, y1, x2, y2)
		else
			bresenham_circle_fill_apply(f, xc, yc, x, y)
		end
	else 
		if clip
			bresenham_circle_clip_apply(f, xc, yc, x, y, x1, y1, x2, y2)
		else
			bresenham_circle_apply(f, xc, yc, x, y)
		end
	end

	while y >= x 
		x += 1

		if d > 0 
			y -= 1 
			d = d + 4 * (x - y) + 10 
		else
			d = d + 4 * x + 6 
		end

		if filled
			if clip
				bresenham_circle_fill_clip_apply(f, xc, yc, x, y, x1, y1, x2, y2)
			else
				bresenham_circle_fill_apply(f, xc, yc, x, y)
			end
		else 
			if clip
				bresenham_circle_clip_apply(f, xc, yc, x, y, x1, y1, x2, y2)
			else
				bresenham_circle_apply(f, xc, yc, x, y)
			end
		end
   end
end


end	# module
