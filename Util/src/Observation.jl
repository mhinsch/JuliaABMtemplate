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



module Observation

export prefixes, @observe

using MacroTools


import Base.print


prefixes(::Type{T}) where {T} = []


function header(out, stat_type, name, sep = "\t", name_sep = "_")
	pref = prefixes(stat_type)
	n = length(pref)

	if n == 0
		print(out, name * sep)
		return
	end

	for p in pref
		print(out, p * name_sep * name * sep)
	end
end


function process_single!(name, expr, header_body, log_body)
	push!(header_body, :(header(output, Nothing, $(esc(name)), FS)))

	push!(log_body, :(print(output, $(esc(expr)), FS)))
end


function process_aggregate!(var, collection, stats, header_body, log_body)
	decl_code = []
	loop_code = []
	output_code = []

	for line in stats.args
		if typeof(line) == LineNumberNode
			continue
		end

		@capture(line, @stat(statname_String, stattypes__) <| expr_) ||
			error("expected: @stat(<NAME>, <STAT> {, <STAT>}) <| <EXPR>,\ngot: $line")

		tmp_name = gensym("tmp")
		push!(loop_code, :($tmp_name = $(esc(expr))))

		for stattype in stattypes
			push!(header_body, :(header(output, $(esc(stattype)), $(esc(statname)), FS)))

			vname = gensym("stat")
			push!(decl_code, :($(esc(vname)) = $(esc(stattype))()))

			push!(loop_code, :($(esc(:add!))($(esc(vname)), $tmp_name)))

			push!(output_code, :(print(output, $(esc(vname)), FS)))
		end
	end

	append!(log_body, decl_code)
	push!(log_body, :(for $(esc(var)) in $(esc(collection)); $(loop_code...); end))
	append!(log_body, output_code)
end


macro observe(fname, model, decl)
	if typeof(fname) != Symbol
		error("@observe expects a function name as 1st argument")
	end

	if typeof(model) != Symbol
		error("@observe expects a model name as 2nd argument")
	end

	if typeof(decl) != Expr || decl.head != :block
		error("@observe expects a declaration block as 3rd argument")
	end


	header_func_name = Symbol("print_header_" * String(fname))
	# use : in order to avoid additional block
	header_func = :(function $(esc(header_func_name))(output; FS="\t", LS="\n")
		end)
	header_body = header_func.args[2].args

	log_func_name = Symbol("print_stats_" * String(fname))
	log_func = :(function $(esc(log_func_name))(output, $(esc(model)); FS="\t", LS="\n", $(esc(:args))...)
		end)
	log_body = log_func.args[2].args


	syntax = "single or population stats declaration expected:\n" *
		"\t@for <NAME> in <EXPR> <BLOCK>" *
		"\t@show <NAME> <EXPR>"
	
	lines = decl.args
	for line in lines
		# filter out line numbers
		if typeof(line) == LineNumberNode
			continue
		end

		if typeof(line) != Expr || line.head != :macrocall
			error(syntax)
		end

		if line.args[1] == Symbol("@show")
			@capture(line, @show(name_String, expr_)) ||
				error("expecting: @show <NAME> <EXPR>")
			process_single!(name, expr, header_body, log_body)
		elseif line.args[1] == Symbol("@for")
			@capture(line, @for var_Symbol in expr_ begin block_ end) ||
				error("expecting: @for <NAME> in <EXPR> <BLOCK>")
			process_aggregate!(var, expr, block, header_body, log_body)
		else
			error(syntax)
		end
	end

	push!(header_body, :(print(output, LS)))
	push!(log_body, :(print(output, LS)))
	push!(log_body, :(flush(output)))

	ret = Expr(:block)
	push!(ret.args, header_func)
	push!(ret.args, log_func)

	ret
end

end	# module
