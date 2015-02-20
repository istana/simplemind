# simplemind.rb

require 'bundler/setup'
require 'active_support/core_ext/object/blank'
require 'sinatra'
require 'slim'
require 'redcarpet'
require 'date'

require_relative 'simplemind_renderer'
require_relative 'simplemind_funny_message'

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


# quasi-models
# use these methods from routes to list files which to render

# the section contains articles
# #index is by default a list to the articles
# returns list of files
def section(model)
	Dir[File.join(settings.content, model.downcase, "#{article_name}*")]
end

# a journal contains articles
# but its articles are concatenated into one article
def journal(model)

end

# concrete page
def article(model)

end



helpers do

	# remove content directory and extension
	def article_url(path)
		parts = path.split('/')
		parts[parts.size-1] = File.basename(parts[parts.size-1], '.*')

		# remove content from the path
		parts.shift

		url('/article/' + parts.join("-"))
	end

	def path_to_article_name(path)
		parts = path.split('/')
		parts[parts.size-1] = File.basename(parts[parts.size-1], '.*')
		parts.join(' / ')
	end
end

helpers Simplemind::FunnyMessage

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


get %r{/article/([[:graph:]]+)} do
	article_name = params[:captures].first.gsub("-", "/")

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
	articles = Dir[File.join('content', '**', '*')].reduce([]) do |result, path|
		if File.file?(path)
			result << [path, File.stat(path).mtime]
		end
	
		result
	end

	articles.sort_by! {|k,v| v}.reverse!

	list = slim :articles_list, locals: { articles: articles, total: articles.size }
	
	halt 200, slim(:main_layout) {
		list
	}
end

