#!/usr/bin/env ruby

encodings = ["ec", "qx", "latin7x", "t8m", "lth"]
# "texnansi", "t5", "lt"

$path_data         = "data"
$filename_AGL      = File.join($path_data, "aglfn13.txt")

$filename_unicode_data = File.join($path_data, "UnicodeData.txt")

$AGL_names = Hash.new()


# read from adobe glyph list
File.open($filename_AGL).grep /^[0-9A-F]+/ do |line|
	unicode, pdfname = line.split(/;/)
	$AGL_names[pdfname] = unicode;
end

$lowercase_letter = Hash.new()
# 00F0;LATIN SMALL LETTER ETH;Ll;0;L;;;;;N;;Icelandic;00D0;;00D0
# FB01;LATIN SMALL LIGATURE FI;Ll;0;L;<compat> 0066 0069;;;;N;;;;;
# lowercase letters
#File.open($filename_unicode_data).grep /^([0-9A-F]*);[^;]*;Ll;.*$/ do |line|
File.open($filename_unicode_data).grep /^([0-9A-F]*);.*$/ do |line|
	unicode, name, lowercase, dummy1, dummy2, compat = line.split(/;/)
	if lowercase == "Ll" then
		unless compat.include?("compat")
			$lowercase_letter[unicode] = true
		end
	# Thai
	elsif unicode.hex >= 0x0E01 and unicode.hex <= 0x0E5B then
		if lowercase =~ /(Lo|Mn)/ then
			$lowercase_letter[unicode] = true
		end
	# Georgian lowercase (lowercase: 'Lo')
	elsif unicode.hex >= 0x10D0 and unicode.hex <= 0x10FA then
		$lowercase_letter[unicode] = true
	end
end


# ij
$lowercase_letter["0133"] = true
# florin
$lowercase_letter["0192"] = false
# ell
$lowercase_letter["2113"] = false

$AGL_names["hyphenchar"] = $AGL_names["hyphen"]
$AGL_names["sfthyphen"] = "00AD"
$AGL_names["hyphen.alt"] = "00AD"

$AGL_names["dotlessj"] = "0237"
$AGL_names["tcedilla"] = "0163"
$AGL_names["Tcedilla"] = "0162"

$AGL_names["ff"]  = "FB00" # = 0066 + 0066
$AGL_names["fi"]  = "FB01" # = 0066 + 0069
$AGL_names["fl"]  = "FB02" # = 0066 + 006C
$AGL_names["ffi"] = "FB03" # = 0066 + 0066 + 0069
$AGL_names["ffl"] = "FB04" # = 0066 + 0066 + 006C

$AGL_names["cwm"] = "200B"
$AGL_names["zerowidthspace"] = "200B"
$AGL_names["perthousandzero"] = "?"
$AGL_names["visiblespace"] = "2423"
#$AGL_names["nbspace"] = "00A0"
$AGL_names["nonbreakingspace"] = "00A0"
$AGL_names["Germandbls"] = "1E9E" # = 0053 + 0053
$AGL_names["ell"] = "2113"

$AGL_names[".notdef"] = "?"

$AGL_names["onesuperior"] = "00B9"
$AGL_names["twosuperior"] = "00B2"
$AGL_names["threesuperior"] = "00B3"

$AGL_names["anglearc"] = "2222"
$AGL_names["diameter"] = "2300"
$AGL_names["dottedcircle"] = "25CC"
$AGL_names["threequartersemdash"] = "?"
$AGL_names["f_k"] = "?"

encodings.each do |enc|
	puts "Writing files for encoding '#{enc}'"

	$filename_encoding         = File.join($path_data, "enc/#{enc}.enc")
	$filename_xetex_mapping    = File.join($path_data, "map/#{enc}.map")
	$filename_encoding2unicode = File.join($path_data, "enc2unicode/#{enc}.dat")


	$file_map = File.open($filename_xetex_mapping, "w")
	# FIXME
	$file_fixed_enc = File.open("data/enc/#{enc}-new.enc", "w")
	$file_encoding2unicode = File.open($filename_encoding2unicode, "w")

	$file_map.print("EncodingName \"TeX-#{enc}\"\n\n")
	$file_map.print("pass(Byte_Unicode)\n\n")

	i = 0
	#$file_out = File.open("#{enc}.txt", "w")
	# read from adobe glyph list
	File.open($filename_encoding).grep(/\/[_a-zA-Z0-9\.]+/) do |line|
		# ignore comments
		line.gsub!(/%.*/,'')
		# encoding name should not be considered
		line.gsub!(/.*\[/,'')
		# nor the ending definition
		line.gsub!(/\].*/,'')
	
		line.scan(/[_a-zA-Z0-9\.]+/) do |w|
			# Adobe Glyph List doesn't contain uniXXXX names,
			# so we add that particular uniXXXX to our list for easier handling later on
			if w =~ /^uni(.*)$/ then
				$AGL_names[w] = $1
			end
			# if the glyph is not in AGL and isn't uniXXXX, print a warning
			if $AGL_names[w] == nil then
				puts sprintf(">> error: %s unknown (index 0x%02X)", w, i)
			else
				#$file_out.printf("%3s %-20s %s\n", i.to_s, w, $AGL_names[w])
				#puts w + " " + $AGL_names[w]
				if $AGL_names[w] == "?"
					$file_map.printf("; %-20s: no Unicode mapping assigned\n", w);
					$file_fixed_enc.printf("/%-15s %% 0x%02X\n", w, i);
					$file_encoding2unicode.printf("0x%02X\tU+....\t\t%s\n", i, w);
				# somewhat unreliable way to filter out uniXXXX.something
				elsif $AGL_names[w].size > 4 then
					$file_map.printf("; %-20s: no unique way to map to Unicode\n", w);
					$file_fixed_enc.printf("/%-15s %% 0x%02X U+%s\n", w, i, $AGL_names[w]);
					$file_encoding2unicode.printf("0x%02X\tU+....\t\t%s\n", i, w);
				else
					unicode_point = $AGL_names[w]
					if i != $AGL_names[w].hex
						$file_map.printf("%d\t<>\tU+%s\t; %s\n", i, unicode_point, w);
						$file_fixed_enc.printf("/%-15s %% 0x%02X U+%s\n", w, i, unicode_point);
					else
						$file_map.printf("%d\t<>\tU+%s\t; %s\n", i, unicode_point, w);
						$file_fixed_enc.printf("/%-15s %% 0x%02X\n", w, i);
					end
					lowercase = ""
					if $lowercase_letter[unicode_point] == true and unicode_point.hex > 127
						lowercase = "1"
						# exception: in Thai, we don't want any characted below 0xA0
						if enc == "lth" and i < 0xA0 then
							lowercase = ""
						end
					end
					$file_encoding2unicode.printf("0x%02X\tU+%s\t%s\t%s\n", i, unicode_point, lowercase, w);
				end
			end
			i = i.next
		end
	end
	#$file_out.close
	$file_map.close
	$file_encoding2unicode.close
end


