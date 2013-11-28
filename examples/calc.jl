# This example mirrors http://www.dabeaz.com/ply/example.html

using PyLexYacc


module rules
	using PyLexYacc

	tokens = (
		"NAME","NUMBER",
		"PLUS","MINUS","TIMES","DIVIDE","EQUALS",
		"LPAREN","RPAREN"
		)

	# Tokens

	t_PLUS    = "\\+"
	t_MINUS   = "-"
	t_TIMES   = "\\*"
	t_DIVIDE  = "/"
	t_EQUALS  = "="
	t_LPAREN  = "\\("
	t_RPAREN  = "\\)"
	t_NAME    = "[a-zA-Z_][a-zA-Z0-9_]*"
	
	t_NUMBER = rule("\\d+") do t, lexer
			t["value"] = int(t["value"])
			return t
		end

	t_ignore  = " \t"

	t_newline = rule("[\\r\\n]+") do t, lexer
			lexer["lineno"] += count((x)->(x == '\n'),t["value"])
			return nothing
		end

	t_error = rule() do t, lexer
			@printf("Illegal character '%s'\n", t["value"][1])
			skip(lexer, 1)
			return t
		end

	precedence = (
			("left", "PLUS", "MINUS"),
			("left", "TIMES", "DIVIDE"),
			("right", "UMINUS")
		)
	
	vars = Dict()  # symbol table

	p_statement_assign = parserule("statement : NAME EQUALS expression") do t
			vars[t[2]] = t[4]
		end

	p_statement_expr = parserule("statement : expression") do t
			println(t[2])
		end

	p_expression_binop = parserule(
			"""expression : expression PLUS expression
			              | expression MINUS expression
			              | expression TIMES expression
			              | expression DIVIDE expression""") do t
			if t[3] == "+"
				t[1] = t[2] + t[4]
			elseif t[3] == "-"
				t[1] = t[2] - t[4]
			elseif t[3] == "*"
				t[1] = t[2] * t[4]
			elseif t[3] == "/"
				t[1] = t[2] / t[4]
			end
		end

	p_expression_uminus = parserule("expression : MINUS expression %prec UMINUS") do t
			t[1] = -t[3]
		end

	p_expression_group = parserule("expression : LPAREN expression RPAREN") do t
			t[1] = t[3]
		end

	p_expression_number = parserule("expression : NUMBER") do t
			t[1] = t[2]
		end

	p_expression_name = parserule("expression : NAME") do t
			try
				t[1] = vars[t[2]]
			catch
				@printf("Undefined name '%s'\n", t[2])
				t[1] = 0
			end
		end

	p_error = rule() do t, lexer  # the error rule actually takes a LexToken so make it a rule()
			@printf("Syntax error at '%s'\n", t["value"][1])
		end
end

l = lexer(rules)
p = parser(rules, "statement")  # specifiy start rule here or through start variable in module

# replicates the input function using in calc.py
function input(str::String)
	print(str)
	return readline(STDIN)
end

println("\\q to quit")
line = input("calc > ")
while chomp(line) != "\\q"
	parse(p, l, line)
	line = input("calc > ")
end