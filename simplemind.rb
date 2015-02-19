# simplemind.rb

require 'bundler/setup'
require 'active_support/inflector'
require 'active_support/core_ext/object/blank'
require 'sinatra'
require 'slim'
require 'redcarpet'
require 'date'

disable :sessions

if settings.environment == :production
	disable :dump_errors
	disable :logging
	disable :show_exceptions
	disable :raise_errors
else
	enable :dump_errors
	enable :logging
	enable :raise_errors
	enable :show_exceptions
	enable :static
end

::Slim::Engine.set_default_options(pretty: true, format: :html5)


# initialize markdown renderer
set :html_renderer, Redcarpet::Render::HTML.new
set :markdown_renderer, Redcarpet::Markdown.new(settings.html_renderer, {
		:no_intra_emphasis => true,
		:tables => true,
		:fenced_code_blocks => true,
		:autolink => true,
		:disable_indented_code_blocks => true,
		:strikethrough => true,
		:lax_spacing => false,
		:space_after_headers => true,
		:superscript => true,
		:underline => true,
		:highlight => true,
		:quote => false,
		:footnotes => true
	})

helpers do
	# remove content directory and extension
	def article_url(path)
		url('/article/' + File.basename(path).gsub(%r{\.[[:graph:]]{2,6}\z}, ""))
	end

	def path_to_article_name(path)
		parts = path.split('/')
		parts[parts.size-1] = File.basename(parts[parts.size-1], '.*')
		parts.join(' / ')
	end

	# write everything in lower case
	def pages_count_message(c)
		if c < 0
			"are we in the antispace yet?"
		elsif c == 0
			"zero. everything has its time, like new posts."
		elsif c == 1
			"they say the first milion is always the hardest. but the first post is probably only testing one."
		elsif c <= 5
			"i'm only getting started."
		elsif c <= 10
			"i'm writing as fast as possible."
		elsif c < 20
			"a handful of posts."
		elsif c < 30
			"i've written more posts than ever."
		elsif c < 40
			"am I good or am I good?"
		elsif c < 60
			"lots of posts. it will be legion of posts some time."
		elsif c < 80
			"i really should find a girlfriend."
		elsif c < 100
			"I love you."
		elsif c < 120
			"holy shit!!!"
		elsif c < 150
			"throng of posts."
		elsif c < 160
			"and now let me code a new CMS."
		elsif c < 180
		  "at this point I've probably written all I wanted. Time to learn to draw?"	
		elsif c < 200
			"thank you, my muses. Calliope, is that you?"
		elsif c < 230
			"thank you, my muses. and bugs. and things that irritate me."
		elsif c < 250
			"Nina Dobrev, will you marry me?"
		elsif c < 280
			"i always wanted a digital library..."
		elsif c <= 300
			"good, the fun begins now..."
		else
			"over 300!!!"
		end
	end
end

def parse_metadata_and_content(text)
	# extract headers separated from content by double new lines
	# category: foobar
	delim_index = text.index("\n\n")

	if delim_index
		nl_index = text[0..delim_index].index("\n")

		# there are no headers
		if nl_index >= delim_index
			metadata = ""
			content = text
		# there is newline and dual newline, so it might be multiple headers. or markdown title
		# do not use colon in the first markdown title :-D
		else
			colon_index = text[nl_index..delim_index].index(":")

			# colon exists = it is a header
			if colon_index
				metadata = text[0..delim_index]
				content = text[delim_index..text.size-1]
			# there is no colon, so probably markdown
			else
				metadata = ""
				content = text
			end
		end
	end
	
	metadata = metadata.split("\n").reduce({}) do |r,l|
		r.merge(Hash[*l.split(":").first(2).map(&:strip).map(&:downcase)])
	end

	[metadata, content]
end

# for text, not fit for attribute values (escape '" additionally)
def text_to_html(text)
	text.gsub("&", "&amp;")
		.gsub("<", "&lt;")
		.gsub(">", "&gt;")
		.gsub("\n", "<br>")
end

def render_markup(text, extension)
	if extension == ".slim"
		slim(text)
	elsif extension =~ /\.(md|mkd|markdown)/
		settings.markdown_renderer.render(text)
	elsif extension == ".txt" || extension == ".text"
		text_to_html(text)
	elsif extension == ".html"
		text
	else
		'unknown markup'
	end
end

get %r{/article/([[:graph:]]+)} do
	article_name = params[:captures].first

	Dir[File.join('content', "#{article_name}*")].each do |f|
		match = f.match(%r{\A(content/[[:graph:]]+(\.(?:slim|md|mkd|markdown|txt|text|html)))\z})

		if match && match[1]
			article = File.read(match[1])
			metadata, content = parse_metadata_and_content(article)

			halt 200, slim(:article, layout: :main_layout) {
				text_to_html(metadata.map{|key, value| "#{key}: #{value}"}.join("\n") + "\n") +
				render_markup(content, match[2])
			}
		else
			halt 500, slim(:article, layout: :main_layout, locals: {
				info: "Article found, but is in unsupported format: #{match[2]}"
			}) { 'foo' }
		end

		# show only one article with the same name
		break
	end

	halt 404, slim(:article, layout: :main_layout, locals: { info: 'Article was not found'}) {
	 	'foobar'
	}
end

get '/' do
	articles = Dir[File.join('content', '**', '*')].map do |path|
		[path, File.stat(path).mtime]
	end

	articles.sort_by! {|k,v| v}.reverse!

	list = slim :articles_list, locals: { articles: articles, total: articles.size }
	
	halt 200, slim(:main_layout) {
		list
	}
end

