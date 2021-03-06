require "sanemark"

module Util
  extend self

  def markdown(text : String, allow_html = false)
    Sanemark.to_html(text, Sanemark::Options.new(allow_html: allow_html, spoilers: true))
  end

  # Gets the title of an article from its path.
  def get_article_title(path : String)
    path = "#{__DIR__}/../content#{path}"
    path += "index" if path.ends_with?("/")
    if File.exists?("#{path}.md")
      path += ".md"
    elsif File.exists?("#{path}.html")
      path += ".html"
    end
    File.read_lines(path).each do |line|
      return line.lchop("TITLE ") if line.starts_with? "TITLE "
    end
  end

  def require_admin(env)
    raise UserErr.new(401) if !env.user
    raise UserErr.new(403) if !env.user.not_nil!.admin
  end
end
