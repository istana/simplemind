# simplemind.rb

require 'bundler/setup'
require 'active_support/inflector'
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

# keep the trailing slash
set :content, 'content/'

::Slim::Engine.set_options(pretty: true, format: :html)

# quasi-models

# the section
#
# world / fonts / sans (opensans.md, verdana.md) <- files from the same section are treated as separate entities
# world / fonts / sans / opensource / (league.md)
# world / fonts / oblique
# women / redheads
#
# only directories are shown
#

def section(uri, &block)
	path = uri_to_file_path(uri)

	Dir[File.join(settings.content, path, "**", "*")].reduce([]) do |r, file|
		if File.directory?(file)
			r << block.call(file)
		end
		r
	end
end

# the journal - the same as the section, but files are flattened????
#
# journals / diary (2015-02-20.md,  2015/02/20.md)
# journals / tech chronicle / 999.md <- another journal
# journals / diary.md <- accepted, treated as already concatenated
#
def journal(uri, &block)
	path = uri_to_file_path(uri)

	Dir[File.join(settings.content, path[0..1])].reduce([]) do |r, file|
		if File.directory?(file)
			r << block.call(file)
		end
		r
	end
end

# articles, like recursive section
#
# articles / me.md
# articles / hardware <- directories are not shown
# articles / hardware / raspberrypi.textile
#
def article(uri, &block)
	path = uri_to_file_path(uri)

	article_query = File.join(settings.content, "#{path}.*")
	articles_query = File.join(settings.content, path, "**", "*")

	# found exact article with some extension
	arts = if Dir[article_query].length > 0
		Dir[article_query]
	else
		# find articles from some point
		Dir[articles_query]
	end

	# filter only files, skip dirs and such
	arts.reduce([]) do |r, file|
		if File.file?(file)
			r << block.call(file)
		end
		r
	end
end

def uri_to_file_path(u)
	raise('uri has no model') if u.blank?

	# convert path to ASCII, be paranoid
	p = ActiveSupport::Inflector.transliterate(u)
	p = p.split("/")
	raise('uri has no model') if p.size == 0

	p.map! do |part|
		# do not allow dots (path traversal) in the uri, only [a-zA-Z_-]
		part.gsub(/[^\w-]/, "")
	end

	p.keep_if {|pa| !pa.blank?}

	# downcase model
	p[0].downcase!

	# and pluralize
	p[0] = ActiveSupport::Inflector.pluralize(p[0])

	# assemble path again
	p.join("/")
end

def file_path_to_uri(path)
	raise('path has no model') if path.blank?

	# convert path to ASCII, be paranoid
	p = ActiveSupport::Inflector.transliterate(path)

	# split path to segments
	p = p.split("/")

	# chop off the extensions, remove remaining dots and other characters
	# handle something like /article/foo.md/photo.jpg
	# valid case: /article/foo.md -> /article/foo
	# uris with extensions are not nice, because they are format dependent
	p.map! do |part|
		part.gsub(/\.\w+\z/, "").gsub(/[^\w-]/, "")
	end

	p.keep_if {|pa| !pa.blank?}

	# remove content folder
	p.shift

	p[0] = ActiveSupport::Inflector.singularize(p[0])

	p.join('/')
end

helpers do
	# remove content directory and extension
	def article_url(path)
		file_path_to_uri(path)
	end

	def path_to_article_name(path)
		file_path_to_uri(path).gsub("/", " / ")
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

#get %r{(/articles/)} do
#	articles = 

#end

get %r{(/article/[[:graph:]]+)} do
	puts params[:captures].inspect
	article(params[:captures].first) do |art|
		article = File.read(art)
		metadata, content = parse_metadata_and_content(article)

		halt 200, slim(:article, layout: :main_layout) {
			metadata.map{|key, value| "#{key}: #{value}"}.join("\n") + "\n" + content
			#(content, match[2])
		}
	end

=begin
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
=end
	halt 404, slim(:article, layout: :main_layout, locals: { info: 'Article was not found'}) {
	 	'foobar'
	}
end

get '/' do
	articles = article('articles') do |file|
		[file, File.stat(file).mtime]
	end

	articles.sort_by! {|k,v| v}.reverse!

	list = slim :articles_list, locals: { articles: articles, total: articles.size }
	
	halt 200, slim(:main_layout) {
		list
	}
end

