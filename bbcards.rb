#!/usr/bin/env ruby

# #######################################################################
#
# bbcards is loosely based on an earlier, but more simplistic project
# called cahgen that also uses ruby/prawn to generate CAH cards,
# which can be found here: https://github.com/jyruzicka/cahgen
#
# bbcards is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 2 of
# the License, or (at your option) any later version.
#
# bbcards is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Hadoop-Gpl-Compression. If not, see
# <http://www.gnu.org/licenses/>
#
#
# #######################################################################


require "prawn"
require "prawn/measurement_extensions"


MM_PER_INCH=25.4

PAPER_NAME   = "LETTER"
PAPER_HEIGHT = (MM_PER_INCH*11.0).mm;
PAPER_WIDTH  = (MM_PER_INCH*8.5).mm;


def get_card_geometry(card_width_inches=2.0, card_height_inches=2.0, rounded_corners=false, one_card_per_page=false)
	card_geometry = Hash.new
	card_geometry["card_width"]        = (MM_PER_INCH*card_width_inches).mm
	card_geometry["card_height"]       = (MM_PER_INCH*card_height_inches).mm
	
	card_geometry["rounded_corners"]   = rounded_corners == true ? ((1.0/8.0)*MM_PER_INCH).mm : rounded_corners
	card_geometry["one_card_per_page"] = one_card_per_page

	if card_geometry["one_card_per_page"]
		card_geometry["paper_width"]       = card_geometry["card_width"]
		card_geometry["paper_height"]      = card_geometry["card_height"]
	else
		card_geometry["paper_width"]       = PAPER_WIDTH
		card_geometry["paper_height"]      = PAPER_HEIGHT
	end


	card_geometry["cards_across"] = (card_geometry["paper_width"] / card_geometry["card_width"]).floor
	card_geometry["cards_high"]   = (card_geometry["paper_height"] / card_geometry["card_height"]).floor

	card_geometry["page_width"]   = card_geometry["card_width"] * card_geometry["cards_across"]
	card_geometry["page_height"]  = card_geometry["card_height"] * card_geometry["cards_high"]

	card_geometry["margin_left"]  = (card_geometry["paper_width"] - card_geometry["page_width"] ) / 2
	card_geometry["margin_top"]   = (card_geometry["paper_height"] - card_geometry["page_height"] ) / 2

	return card_geometry;

end

def draw_grid(pdf, card_geometry)
	
	pdf.stroke do
		if card_geometry["rounded_corners"] == false
			#Draw vertical lines
			0.upto(card_geometry["cards_across"]) do |i|
				pdf.line(
					[card_geometry["card_width"]*i, 0],
					[card_geometry["card_width"]*i, card_geometry["page_height"]]
					)
			end
		
			#Draw horizontal lines
			0.upto(card_geometry["cards_high"]) do |i|
				pdf.line(
					[0,                           card_geometry["card_height"]*i],
					[card_geometry["page_width"], card_geometry["card_height"]*i]
					)
		
			end
		else
			0.upto(card_geometry["cards_across"]-1) do |i|
				0.upto(card_geometry["cards_high"]-1) do |j|
					#rectangle bounded by upper left corner, horizontal measured from the left, vertical measured from the bottom
					pdf.rounded_rectangle(
								[i*card_geometry["card_width"], card_geometry["card_height"]+(j*card_geometry["card_height"])], 
								card_geometry["card_width"],
								card_geometry["card_height"], 
								card_geometry["rounded_corners"]
								)
				end
			end
		end
	end
end

def box(pdf, card_geometry, index, &blck)
	# Determine row + column number
	column = index%card_geometry["cards_across"]
	row = card_geometry["cards_high"] - index/card_geometry["cards_across"]

	# Margin: 10pt
	x = card_geometry["card_width"] * column + 10
	y = card_geometry["card_height"] * row - 10

	pdf.bounding_box([x,y], width: card_geometry["card_width"]-20, height: card_geometry["card_height"]-10, &blck)
end

def draw_logos(pdf, card_geometry, icon)
	idx=0
	while idx < card_geometry["cards_across"] * card_geometry["cards_high"]
		box(pdf, card_geometry, idx) do
			logo_max_height = 15
			logo_max_width = card_geometry["card_width"]/2
			pdf.image icon, fit: [logo_max_width,logo_max_height], at: [pdf.bounds.left,pdf.bounds.bottom+25]
		end
		idx = idx + 1
	end
end




def render_card_page(pdf, card_geometry, icon, statements, is_black)
	
	pdf.font "Helvetica", :style => :normal
	pdf.font_size = 14
	pdf.line_width(0.5);

	
	if(is_black)
		pdf.canvas do
			pdf.rectangle(pdf.bounds.top_left,pdf.bounds.width, pdf.bounds.height)
		end

		pdf.fill_and_stroke(:fill_color=>"000000", :stroke_color=>"000000") do
			pdf.canvas do
				pdf.rectangle(pdf.bounds.top_left,pdf.bounds.width, pdf.bounds.height)
			end
		end
		pdf.stroke_color "ffffff"
		pdf.fill_color "ffffff"
	else
		pdf.stroke_color "000000"
		pdf.fill_color "000000"
	end

	draw_grid(pdf, card_geometry)
	statements.each_with_index do |line, idx|
		box(pdf, card_geometry, idx) do
			
			line_parts = line.split(/\t/)
			card_text = line_parts.shift
			card_text = card_text.gsub(/\\n */, "\n")
			card_text = card_text.gsub(/\\t/,   "\t")

			card_text = card_text.gsub("<b>", "[[[b]]]")
			card_text = card_text.gsub("<i>", "[[[i]]]")
			card_text = card_text.gsub("<u>", "[[[u]]]")
			card_text = card_text.gsub("<strikethrough>", "[[[strikethrough]]]")
			card_text = card_text.gsub("<sub>", "[[[sub]]]")
			card_text = card_text.gsub("<sup>", "[[[sup]]]")
			card_text = card_text.gsub("<font", "[[[font")
			card_text = card_text.gsub("<color", "[[[color")
			card_text = card_text.gsub("<br>", "[[[br/]]]")
			card_text = card_text.gsub("<br/>", "[[[br/]]]")
			card_text = card_text.gsub("<br />", "[[[br/]]]")

			card_text = card_text.gsub("</b>", "[[[/b]]]")
			card_text = card_text.gsub("</i>", "[[[/i]]]")
			card_text = card_text.gsub("</u>", "[[[/u]]]")
			card_text = card_text.gsub("</strikethrough>", "[[[/strikethrough]]]")
			card_text = card_text.gsub("</sub>", "[[[/sub]]]")
			card_text = card_text.gsub("</sup>", "[[[/sup]]]")
			card_text = card_text.gsub("</font>", "[[[/font]]]")
			card_text = card_text.gsub("</color>", "[[[/color]]]")


			card_text = card_text.gsub(/</, "&lt;");

			
			card_text = card_text.gsub("\[\[\[b\]\]\]", "<b>")
			card_text = card_text.gsub("\[\[\[i\]\]\]", "<i>")
			card_text = card_text.gsub("\[\[\[u\]\]\]", "<u>")
			card_text = card_text.gsub("\[\[\[strikethrough\]\]\]", "<strikethrough>")
			card_text = card_text.gsub("\[\[\[sub\]\]\]", "<sub>")
			card_text = card_text.gsub("\[\[\[sup\]\]\]", "<sup>")
			card_text = card_text.gsub("\[\[\[font", "<font")
			card_text = card_text.gsub("\[\[\[color", "<color")
			card_text = card_text.gsub("\[\[\[br/\]\]\]", "<br/>")

			card_text = card_text.gsub("\[\[\[/b\]\]\]", "</b>")
			card_text = card_text.gsub("\[\[\[/i\]\]\]", "</i>")
			card_text = card_text.gsub("\[\[\[/u\]\]\]", "</u>")
			card_text = card_text.gsub("\[\[\[/strikethrough\]\]\]", "</strikethrough>")
			card_text = card_text.gsub("\[\[\[/sub\]\]\]", "</sub>")
			card_text = card_text.gsub("\[\[\[/sup\]\]\]", "</sup>")
			card_text = card_text.gsub("\[\[\[/font\]\]\]", "</font>")
			card_text = card_text.gsub("\[\[\[/color\]\]\]", "</color>")

			

			parts = card_text.split(/\[\[/)
			card_text = ""
			first = true
			previous_matches = false
			parts.each do |p|
				n = p
				this_matches=false
				if p.match(/\]\]/)
					s = p.split(/\]\]/)
					line_parts.push(s[0])
					if s.length > 1
						n = s[1]
					else
						n = ""
					end
					this_matches=true
				end

				if first
					card_text = n.to_s
				elsif this_matches
					card_text = card_text + n
				else
					card_text = card_text + "[[" + n
				end
				first = false
			end
			card_text = card_text.gsub(/^[\t ]*/, "")
			card_text = card_text.gsub(/[\t ]*$/, "")


			
			is_pick2 = false
			is_pick3 = false
			if is_black
				pick_num = line_parts.shift
				if pick_num.nil? or pick_num == ""
					tmpline = "a" + card_text.to_s + "a"
					parts = tmpline.split(/__+/)
					if parts.length == 3
						is_pick2 = true
					elsif parts.length >= 4
						is_pick3 = true
					end
				elsif pick_num == "2"
					is_pick2 = true
				elsif pick_num == "3"
					is_pick3 = true
				end

			end

			
			picknum = "0"
			if is_pick2
				picknum = "2"
			elsif is_pick3
				picknum = "3"
			elsif is_black
				picknum = "1"
			end

			statements[idx] = [card_text,picknum]

			#by default cards should be bold
			card_text = "<b>" + card_text + "</b>"



			# Text
			pdf.font "Helvetica", :style => :normal

			if is_pick3
				pdf.text_box card_text.to_s, :overflow => :shrink_to_fit, :height =>card_geometry["card_height"]-55, :inline_format => true
			else
				pdf.text_box card_text.to_s, :overflow => :shrink_to_fit, :height =>card_geometry["card_height"]-35, :inline_format => true
			end
	
			pdf.font "Helvetica", :style => :bold
			#pick 2
			if is_pick2
				pdf.text_box "PICK", size:11, align: :right, width:30, at: [pdf.bounds.right-50,pdf.bounds.bottom+20]
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+15.5],7.5)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "2", color:"000000", size:14, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+21]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"
			end
	
			#pick 3
			if is_pick3
				pdf.text_box "PICK", size:11, align: :right, width:30, at: [pdf.bounds.right-50,pdf.bounds.bottom+20]
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+15.5],7.5)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "3", color:"000000", size:14, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+21]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"


				pdf.text_box "DRAW", size:11, align: :right, width:35, at: [pdf.bounds.right-55,pdf.bounds.bottom+40]
				pdf.fill_and_stroke(:fill_color=>"ffffff", :stroke_color=>"ffffff") do
					pdf.circle([pdf.bounds.right-10,pdf.bounds.bottom+35.5],7.5)
				end
				pdf.stroke_color '000000'
				pdf.fill_color '000000'
				pdf.text_box "2", color:"000000", size:14, width:8, align: :center, at:[pdf.bounds.right-14,pdf.bounds.bottom+41]
				pdf.stroke_color "ffffff"
				pdf.fill_color "ffffff"
			end
		end
	end
	draw_logos(pdf, card_geometry, icon)
	pdf.stroke_color "000000"
	pdf.fill_color "000000"

end

def load_pages_from_lines(lines, card_geometry)
	pages = []

	non_empty_lines = []
	lines.each do |line|
		line = line.gsub(/^[\t\n\r]*/, "")
		line = line.gsub(/[\t\n\r]*$/, "")
		if line != ""
			non_empty_lines.push(line)
		end
	end
	lines = non_empty_lines


	cards_per_page = card_geometry["cards_high"] * card_geometry["cards_across"]
	num_pages = (lines.length.to_f/cards_per_page.to_f).ceil
		
	0.upto(num_pages - 1) do |pn|
 		pages << lines[pn*cards_per_page,cards_per_page]
    	end

	return pages

end


def load_pages_from_string(string, card_geometry)
	lines = string.split(/[\r\n]+/)
	pages = load_pages_from_lines(lines, card_geometry)
	return pages
end

def load_pages_from_file(file, card_geometry)
	pages = []
	if File.exist?(file)
		lines = IO.readlines(file)
		pages = load_pages_from_lines(lines, card_geometry);
	end
	return pages
end


def load_ttf_fonts(font_dir, font_families)
	
	if font_dir.nil?
		return
	elsif (not Dir.exist?(font_dir)) or (font_families.nil?)
		return
	end

	font_files = Hash.new
	ttf_files=Dir.glob(font_dir + "/*.ttf")
	ttf_files.each do |ttf|
		full_name = ttf.gsub(/^.*\//, "")
		full_name = full_name.gsub(/\.ttf$/, "")
		style = "normal"
		name = full_name
		if name.match(/_Bold_Italic$/)
			style = "bold_italic"
			name = name.gsub(/_Bold_Italic$/, "")
		elsif name.match(/_Italic$/)
			style = "italic"
			name = name.gsub(/_Italic$/, "")
		elsif name.match(/_Bold$/)
			style = "bold"	
			name = name.gsub(/_Bold$/, "")
		end

		name = name.gsub(/_/, " ");

		if not (font_files.has_key? name)
			font_files[name] = Hash.new
		end
		font_files[name][style] = ttf
	end

	font_files.each_pair do |name, ttf_files|
		if (ttf_files.has_key? "normal" ) and (not font_families.has_key? "name" )
			normal = ttf_files["normal"]
			italic = (ttf_files.has_key? "italic") ?  ttf_files["italic"] : normal
			bold   = (ttf_files.has_key? "bold"  ) ?  ttf_files["bold"]   : normal
			bold_italic = normal
			if ttf_files.has_key? 'bold_italic'
				bold_italic = ttf_files["bold_italic"]
			elsif ttf_files.has_key? 'italic'
				bold_italic = italic
			elsif ttf_files.has_key? 'bold'
				bold_italic = bold
			end
			
			
			font_families.update(name => {
				:normal => normal,
				:italic => italic,
				:bold => bold,
				:bold_italic => bold_italic
			})

		end
	end
end


def render_cards(directory=".", white_file="white.txt", black_file="black.txt", icon_file="icon.png", output_file="cards.pdf", input_files_are_absolute=false, output_file_name_from_directory=true, recurse=true, card_geometry=get_card_geometry, white_string="", black_string="", output_to_stdout=false, title=nil )
	
	original_white_file = white_file
	original_black_file = black_file
	original_icon_file = icon_file
	if not input_files_are_absolute
		white_file = directory + File::Separator + white_file
		black_file = directory + File::Separator + black_file
		icon_file  = directory + File::Separator + icon_file
	end

	if not File.exist? icon_file
		icon_file = "./default.png"
	end


	if not directory.nil?
		if File.exist?(directory) and directory != "." and output_file_name_from_directory
			output_file = directory.split(File::Separator).pop + ".pdf"
		end
	end
	
	if output_to_stdout and title.nil?
		title = "Bigger, Blacker Cards"
	elsif title.nil? and output_file != "cards.pdf"
		title = output_file.split(File::Separator).pop.gsub(/.pdf$/, "")
	end
	

	
	white_pages = []
	black_pages = []
	if white_file == nil and black_file == nil and white_string == "" and black_string == ""
		white_string = " "
		black_string = " "
	end
	if white_string != "" || white_file == nil
		white_pages = load_pages_from_string(white_string, card_geometry)
	else
		white_pages = load_pages_from_file(white_file, card_geometry)
	end
	if black_string != "" || black_file == nil
		black_pages = load_pages_from_string(black_string, card_geometry)
	else
		black_pages = load_pages_from_file(black_file, card_geometry)
	end
		
	
	
	if white_pages.length > 0 or black_pages.length > 0
		pdf = Prawn::Document.new(
			page_size: [card_geometry["paper_width"], card_geometry["paper_height"]],
			left_margin: card_geometry["margin_left"],
			right_margin: card_geometry["margin_left"],
			top_margin: card_geometry["margin_top"],
			bottom_margin: card_geometry["margin_top"],
			info: { :Title => title, :CreationDate => Time.now, :Producer => "Bigger, Blacker Cards", :Creator=>"Bigger, Blacker Cards" }
			)
		load_ttf_fonts("/usr/share/fonts/truetype/msttcorefonts", pdf.font_families)


		white_pages.each_with_index do |statements, page|
			render_card_page(pdf, card_geometry, icon_file, statements, false)
			pdf.start_new_page unless page >= white_pages.length-1
		end
		pdf.start_new_page unless white_pages.length == 0 || black_pages.length == 0
		black_pages.each_with_index do |statements, page|
			render_card_page(pdf, card_geometry, icon_file, statements, true)
			pdf.start_new_page unless page >= black_pages.length-1
		end

		if output_to_stdout
			puts "Content-Type: application/pdf"
			puts ""
			print pdf.render
		else
			pdf.render_file(output_file)
		end
	end

	if (not input_files_are_absolute) and recurse
		files_in_dir =Dir.glob(directory + File::Separator + "*")
		files_in_dir.each do |subdir|
			if File.directory? subdir
				render_cards(subdir, original_white_file, original_black_file, original_icon_file, "irrelevant", false, true, true, card_geometry )
			end
		end
	end

end

def parse_args(variables=Hash.new, flags=Hash.new, save_orphaned=false, argv=ARGV)
	
	parsed_args = Hash.new
	orphaned = Array.new

	new_argv=Array.new
	while argv.length > 0
		next_arg = argv.shift
		if variables.has_key? next_arg
			arg_name = variables[next_arg]
			parsed_args[arg_name] = argv.shift
		elsif flags.has_key? next_arg
			flag_name = flags[next_arg]
			parsed_args[flag_name] = true
		else
			orphaned.push next_arg
		end
		new_argv.push next_arg
	end
	if save_orphaned
		parsed_args["ORPHANED_ARGUMENT_ARRAY"] = orphaned
	end

	while new_argv.length > 0
		argv.push new_argv.shift
	end

	return parsed_args
end






def print_help
	puts "USAGE:"
	puts "\tbbcards --directory [CARD_FILE_DIRECTORY]"
	puts "\tOR"
	puts "\tbbcards --white [WHITE_CARD_FILE] --black [BLACK_CARD_FILE] --icon [ICON_FILE] --output [OUTPUT_FILE]"
	puts ""
	puts "bbcards expects you to specify EITHER a directory or"
	puts "specify a path to black/white card files. If both are"
	puts "specified, it will ignore the indifidual files and generate"
       	puts "cards from the directory."
	puts ""
	puts "If you specify a directory, white cards will be loaded from"
       	puts "a file white.txt in that directory and black cards from"
	puts "black.txt. If icon.png exists in that directory, it will be"
       	puts "used to generate the card icon on the lower left hand side of"
	puts "the card. The output will be a pdf file with the same name as"
	puts "the directory you specified in the current working directory."
	puts "bbcards will descend recursively into any directory you"
	puts "specify, generating a separate pdf for every directory that"
	puts "contains black.txt, white.txt or both."
	puts ""
	puts "You may specify the card size by passing either the --small"
	puts " or --large flag.  If you pass the --small flag then small"
	puts "cards of size 2\"x2\" will be produced. If you pass the --large"
	puts "flag larger cards of size 2.5\"x3.5\" will be produced. Small"
	puts "cards are produced by default."
	puts ""
	puts "All flags:"
	puts "\t-b,--black\t\tBlack card file"
	puts "\t-d,--dir\t\tDirectory to search for card files"
	puts "\t-h,--help\t\tPrint this Help message"
	puts "\t-i,--icon\t\tIcon file, should be .jpg or .png"
	puts "\t-l,--large\t\tGenerate large 2.5\"x3.5\" cards"
	puts "\t-o,--output\t\tOutput file, will be a .pdf file"
	puts "\t-s,--small\t\tGenerate small 2\"x2\" cards"
	puts "\t-w,--white\t\tWhite card file"
	puts ""
	

end


if not (ENV['REQUEST_URI']).nil?

	require 'cgi'
	cgi = CGI.new( :accept_charset => "UTF-8" )
	
	white_cards = cgi["whitecards"]
	black_cards = cgi["blackcards"]
	card_size   = cgi["cardsize"]
	page_layout = cgi["pagelayout"]
	icon = "default.png"
	if cgi["icon"] != "default"
		params = cgi.params
		tmpfile = cgi.params["iconfile"].first
		if not tmpfile.nil?
			icon = "/tmp/" + (rand().to_s) + "-" + tmpfile.original_filename
			File.open(icon.untaint, "w") do |f|
    				f << tmpfile.read(1024*1024)
			end
		end
	end
	
	
	one_per_page    = page_layout == "oneperpage" ? true : false
	rounded_corners = card_size    == "LR"         ? true : false
	card_geometry   = card_size    == "S" ? get_card_geometry(2.0,2.0,rounded_corners,one_per_page) : get_card_geometry(2.5,3.5,rounded_corners,one_per_page)
	
	render_cards nil, nil, nil, icon, "cards.pdf", true, false, false, card_geometry, white_cards, black_cards, true

	if icon != "default.png"
		File.unlink(icon)
	end

else
	arg_defs  = Hash.new
	flag_defs = Hash.new
	arg_defs["-b"]          = "black"
	arg_defs["--black"]     = "black"
	arg_defs["-w"]          = "white"
	arg_defs["--white"]     = "white"
	arg_defs["-d"]          = "dir"
	arg_defs["--directory"] = "dir"
	arg_defs["-i"]          = "icon"
	arg_defs["--icon"]      = "icon"
	arg_defs["-o"]          = "output"
	arg_defs["-output"]     = "output"

	flag_defs["-s"]            = "small"
	flag_defs["--small"]       = "small"
	flag_defs["-l"]            = "large"
	flag_defs["--large"]       = "large"
	flag_defs["-r"]            = "rounded"
	flag_defs["--rounded"]     = "rounded"
	flag_defs["-p"]            = "oneperpage"
	flag_defs["--oneperpage"]  = "oneperpage"
	flag_defs["-h"]            = "help"
	flag_defs["--help"]        = "help"


	args = parse_args(arg_defs, flag_defs)
	card_geometry = get_card_geometry(2.0,2.0, !(args["rounded"]).nil?, !(args["oneperpage"]).nil? )
	if args.has_key? "large"
		card_geometry = get_card_geometry(2.5,3.5, (not (args["rounded"]).nil?), (not (args["oneperpage"]).nil? ))
	end
	
	if args.has_key? "help" or args.length == 0 or ( (not args.has_key? "white") and (not args.has_key? "black") and (not args.has_key? "dir") )
		print_help
	elsif args.has_key? "dir"
		render_cards args["dir"], "white.txt", "black.txt", "icon.png", "cards.pdf", false, true, true, card_geometry, "", "", false
	else
		render_cards nil, args["white"], args["black"], args["icon"], args["output"], true, false, false, card_geometry, "", "", false
	end
end
exit


