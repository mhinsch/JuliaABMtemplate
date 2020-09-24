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



# This package provides some nice convenience syntax for parameters.
# Specifically we can set default values for struct elements. A constructor is
# then created that a) has all struct elements as named args and b) sets the
# value of elements to the default values if they are not specified on calling
# the constructor
using Parameters


"Simulation parameters"
@with_kw struct Params
	# element documentation is automatically translated into commandline help text

	"infection rate"
	r_inf	:: Float64 = 0.1
	"recovery rate"
	r_rec	:: Float64 = 0.1
	"rate of acquiring immunity"
	r_imm	:: Float64 = 0.1
	"mortality rate"
	r_mort	:: Float64 = 0.1

	"world width (only matrix)"
	x 		:: Int = 50
	"world height (only matrix)"
	y 		:: Int = 50

	"number of agents (only geo graph)"
	N 		:: Int = 2500
	"distance threshold for connections (only geo graph)"
	near 	:: Float64 = 0.03
	"number of global connections (only geo graph)"
	nc 		:: Int = 20
end
