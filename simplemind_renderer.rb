# conform to HTML5
#
# markdown
require 'redcarpet'
# textile
require 'redcloth'
# slim
require 'slim'
# html
require 'sanitize'
# source code highlighter
require 'rouge'

# redcarpet highlights source code in marked fenced blocks in markdown
require 'rouge/plugins/redcarpet'

class HTML < Redcarpet::Render::HTML
	include Rouge::Plugins::Redcarpet
end

require 'active_support/core_ext/hash'

module Simplemind
	class Renderer
		# final function
		def gogogo
			if !@options[:file_path].blank?
				file_ext = @options[:file_path].match(%r{\.([[:graph:]]+)\z})[1]

				if file_ext
					@options[:parsers].each do |p|
						apply_parser(p)
					end if @options[:parsers]

					@options[:filters].each do |f|
						apply_filter(f)
					end if @options[:filters]

					apply_renderer(file_ext)
				else
					raise("Extension could not be extracted: '#{@options[:file_path]}'")
				end

				{
					:metadata => @metadata.symbolize_keys!,
					:content => @text
				}
			else
				raise('could not render text')
			end
		end

		def self.read(file_path)
			if File.exists?(file_path) && File.file?(file_path)
				new(File.read(file_path)).options(file_path: file_path)
			else
				nil
			end
		end

		def initialize(text)
			@metadata = {}
			@text = text
			@options = {}

			# I don't like class variables here
			#register_renderer('slim', ::Simplemind::Markup.slim)
			register_renderer('md', 'markdown')
			register_renderer('markdown', 'markdown')
			register_renderer('txt', 'text')
			register_renderer('text', 'text')
			register_renderer('html', 'html')
			register_renderer('textile', 'textile')

			register_filter('highlight_source_code', 'highlight_source_code')

			register_parser('split_metadata_and_content', 'split_metadata_and_content')
			register_parser('extract_title', 'extract_title')
			self
		end

		def options(opts)
			@options.merge!(opts.symbolize_keys!)
			self
		end

		def filter(which)
			@options[:filters] ||= []
			@options[:filters] << which.to_sym
			self
		end

		def parser(which)
			@options[:parsers] ||= []
			@options[:parsers] << which.to_sym
			self
		end

		def metadata
			@metadata.symbolize_keys!
		end

		private

		def register_filter(name, method)
			@filters ||= {}
			@filters[name.to_sym] = method
		end

		def register_renderer(which, markup)
			@renderers ||= {}
			@renderers[which.to_sym] = markup
		end

		def register_parser(name, method)
			@parsers ||= {}
			@parsers[name.to_sym] = method
		end

		def apply_filter(which)
			filter = @filters[which.to_sym]

			if filter
				@text = ActiveSupport::Inflector.constantize('::Simplemind::Filter')
					.send(filter, @text, @options)
			else
				raise("Filter not found: #{which}")
			end
		end

		def apply_renderer(file_ext)
			renderer = @renderers[file_ext.to_sym]

			if renderer
				@text = ActiveSupport::Inflector.constantize('::Simplemind::Markup')
					.send(renderer, @text, @options)
			else
				raise("Renderer for extension not found: #{file_ext}")
			end
		end

		def apply_parser(which)
			parser = @parsers[which.to_sym]

			if parser
				res = ActiveSupport::Inflector.constantize('::Simplemind::Parser')
					.send(parser, @metadata, @text, @options)

				@metadata = res[:metadata]
				@text = res[:content]
			else
				raise("Parser not found: #{which}")
			end
		end
	end

	module Markup
		# escape that characters and convert newlines
		# do not insert the result of this into attributes names
		# in this case escape " and ' additionally
		# returns content
		def self.text(text, options)
			text.gsub("&", "&amp;")
				.gsub("<", "&lt;")
				.gsub(">", "&gt;")
				.gsub("\n", "<br>")
		end

		def self.html(text, options)
			# like do nothing?
			text
			# use sanitizer in public security
		end

		def self.markdown(text, options)
			formatter = Redcarpet::Render::HTML.new
			renderer = Redcarpet::Markdown.new(formatter, {
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

			renderer.render(text)
		end

		def self.textile(text, options)
			RedCloth.new(text).to_html
		end

		#def slim(text, options)
		#	slim(text)
		#end	
	end

	# filters modifies content like syntax highlighting
	# or censoring, replacing placeholders and such
	# returns content
	module Filter
		# well, shit, no libraries for language detection from the snippet
		# for now just markdown will work
		def self.highlight_source_code(source, options = {})
			formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
			formatter.format(lexer.lex(source))
		end
	end

	# parsers extracts data from the content into separate variables
	# think of reduce
	# e.g. extract metadata
	# returns hash with metadata and content
	module Parser
		def self.split_metadata_and_content(metadata_orig, text, options = {})
			# extract headers separated from content by double new lines
			# category: foobar
			delim_index = text.index("\n\n")

			if delim_index
				nl_index = text[0..delim_index].index("\n")

				# there are no headers
				if (nl_index >= delim_index) && delim_index == 0
					puts 'no_headers'
					metadata = ""
					content = text
				elsif delim_index > 0
					# there is one header
					if (nl_index >= delim_index)
						colon_index = text[0..nl_index].index(":")
					# there are more headers
					else
						colon_index = text[nl_index..delim_index].index(":")
					end

					# colon exists = it is a header section
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

			{
				:metadata => metadata_orig.merge(metadata),
				:content => content
			}
		end

		# extract markdown or textile h1 header from the text and adds into metadata
		def self.extract_title(metadata_orig, text, options = {})
			title = nil
			content = text


			# skip whitespaces on the beginng 
			offset = 0
			while text[offset] =~ /\s/
				offset += 1
			end

			first_nl = text.index("\n", offset)

			if first_nl && (text[0..first_nl] =~ /\A\s+#/ || text[0..first_nl] =~ /\A\s+h1\./)
				title = text[0..first_nl].gsub('#', '').gsub('h1.', '').strip
				content = text[first_nl..text.size-1].strip

				return({
					:metadata => metadata_orig.merge(title: title),
					:content => content
				})
			end

			{
				:metadata => metadata_orig,
				:content => text
			}
		end

	end
end

