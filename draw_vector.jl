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



using Luxor


function draw_sim(sim, p_size = 5, w_size = 600)
	max_x = mapreduce(p -> p.x, max, sim.pop)
	max_y = mapreduce(p -> p.y, max, sim.pop)
	min_x = mapreduce(p -> p.x, min, sim.pop)
	min_y = mapreduce(p -> p.y, min, sim.pop)

	f_scale = 600 / max(max_x - min_x, max_y - min_y)

	@svg begin
		p_size = 5
		
		origin(0, 0)

		sethue("black")
		
		for p in sim.pop
			x1 = p.x * f_scale
			y1 = p.y * f_scale
			
			for p2 in p.contacts
				x2 = p2.x * f_scale
				y2 = p2.y * f_scale
				
				setline(1)
				setdash("solid")
				line(Point(x1, y1), Point(x2, y2), :stroke)
			end
		end

		
		for p in sim.pop
			x = p.x * f_scale
			y = p.y * f_scale
			
			if p.status == infected
				sethue("red")
			elseif p.status == immune
				sethue("green")
			elseif p.status == susceptible
				sethue("blue")
			elseif p.status == dead
				sethue("grey")
			end
			
			circle(Point(x, y), p_size, :fill)
		end
	end
end
