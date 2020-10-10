#!/usr/bin/env crystal

require "sanemark"
require "option_parser"
require "ecr"

require "../cfg"
require "./templates"

CONTENT_DIR = Path.new(__DIR__ + "/../../content").expand.to_s
DEPLOY_DIR  = Path.new(__DIR__ + "/../../html").expand.to_s

# Reads the specified file, determines the appropriate correspondent in the deploy folder, and creates it.
def process_file(filename)
  infile = File.expand_path(filename)
  outfile = (infile.sub CONTENT_DIR, DEPLOY_DIR).chomp(".html").chomp ".md"
  # If it's a directory, create it in the deployment dir if it doesn't exist, then recurse into it.
  if File.directory? infile
    Dir.mkdir outfile if !File.exists? outfile
    Dir.children(infile).each { |child| process_file (File.join [infile, child]) }
    return
  end
  puts "#{infile} -> #{outfile}"
  # If it's not a templated filetype, hard link it instead.
  if !{".html", ".md"}.includes?(File.extname filename)
    # Have to remove it first if it exists but it's the wrong file.
    if File.exists?(outfile) && !File.same? infile, outfile
      File.delete(outfile)
    end
    File.link infile, outfile if !File.exists? outfile
    return
  end
  begin
    output = build_article infile
  rescue error
    STDERR.puts "Couldn't process #{infile}: #{error}"
  end
  File.write outfile, output
end

# Takes the name of an article file and returns the content of the output file.
def build_article(file)
  header, _, body = File.read(file).partition "\n\n"
  args = parse_directives(header)
  raise "The TITLE directive is required." if !args["TITLE"]?
  args["TIMESTAMP"] = Time.utc
  args["PATH"] = Path.new(file).relative_to(CONTENT_DIR).to_s.chomp(".html").chomp(".md")
  args["NAV"] = navbar_html(args["PATH"].as(String), args["NAV"]?.try &.as(String), args["TITLE"].as(String))
  args["BODY"] = file.ends_with?(".md") ? Sanemark.to_html(body, Sanemark::Options.new(allow_html: true)) : body
  TEMPLATES[args["TEMPLATE"]? || "default"].call args
end

# Parses the settings at the top of an article file and returns them as a hash.
def parse_directives(header)
  args = {"JS" => [] of String, "CSS" => [] of String} of String => TemplateArg
  header.split("\n").each do |line|
    param, _, val = line.partition " "
    if val == ""
      args[param] = true
    elsif {"JS", "CSS"}.includes? param
      args[param].as Array << val
    else
      args[param] = val
    end
  end
  args
end

# Computes the HTML for the navbar from the path of the page and the NAV setting.
# Note that `path` should not include the leading slash.
def navbar_html(path : String, nav : String | Nil, title : String)
  return CFG.site_title if path == "index"
  path = path.chomp("/index")
  navhtml = "<a style=\"color:yellow\" href=\"/\">#{CFG.site_title}</a>"
  running_path = "/"
  path.split("/")[..-2].each do |piece|
    running_path = File.join [running_path, piece]
    # Determine the nav directive of the directory.
    name = begin
      # Try both index.md and index.html.
      begin
        index_file = File.read(File.join [CONTENT_DIR, running_path, "index.md"])
      rescue File::NotFoundError
        index_file = File.read(File.join [CONTENT_DIR, running_path, "index.html"])
      end
      index_settings = index_file.partition("\n\n")[0]
      parse_directives(index_settings)["NAV"].as(String)
    rescue e : File::NotFoundError | KeyError
      # If there isn't an index file or it doesn't have a NAV, normalize the directory's name.
      piece.gsub(/[_-]/, " ").titleize
    end
    navhtml += " &gt; <a style=\"color:yellow\" href=\"#{running_path}/\">#{name}</a>"
  end
  navhtml + " &gt; " + (nav || title)
end

OptionParser.parse do |parser|
  parser.banner = "Usage: tmpl <files ...>\n" +
                  "Folders will be recursed.\n" +
                  "Options:\n"
  parser.on "-o", "--stdout", "write output to stdout instead of to the deployment dir." { stdout = true }
  parser.invalid_option do |opt|
    STDERR.puts "Unrecognized option: #{opt}"
    STDERR.puts parser
    exit 1
  end
end
(ARGV.empty? ? [CONTENT_DIR] : ARGV).each { |arg| process_file arg }
