# conform to HTML5
#
# markdown
require 'redcarpet'
# textile
require 'redcloth'
# html
require 'sanitize'
# source code highlighter
require 'rouge'

# redcarpet highlights source code in marked fenced blocks in markdown
require 'rouge/plugins/redcarpet'

class HTML < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet
end

module Simplemind
	class Renderer
		# final function
		def to_html
			if !@options[:file_path].blank?
				file_ext[1] = @options[:file_path].match(%r{\.([[:graph:]]+)\z})

				renderer = @renderers[file_ext]

				raise('renderer not found') if !renderer

				result = renderer(@result, @options)

				@options[:filters].each do |usefilter|
					filter = @filters[usefilter]
					result = filter(result, @options)
				end
			else
				raise('could not render text')
			end
			result
		end

		def self.read(file_path)
			if File.exists?(file_path) && File.file?(file_path)
				new(File.read(file_path)).options(file_path: 'file_path')
			else
				nil
			end
		end

		def initialize(text)
			@result = nil
			@options = {}

			# I don't like class variables here
			register_renderer('slim', ::Simplemind::Markup.slim)
			register_renderer('md', ::Simplemind::Markup.markdown)
			register_renderer('markdown', ::Simplemind::Markup.markdown)
			register_renderer('txt', ::Simplemind::Markup.text)
			register_renderer('text', ::Simplemind::Markup.text)
			register_renderer('html', ::Simplemind::Markup.html)
			register_renderer('textile', ::Simplemind::Markup.textile)

			register_filter('source_code', ::Simplemind::Filter.highlight_source_code)

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

		private

		def register_filter(ext, filter)
			@filters[ext.to_sym] = filter
		end

		def register_renderer(which, markup)
			@renderers[which.to_sym] = markup
		end
	end

	module Markup
		# escape that characters and convert newlines
		# do not insert the result of this into attributes names
		# in this case escape " and ' additionally
		def text(text, options)
			text.gsub("&", "&amp;")
				.gsub("<", "&lt;")
				.gsub(">", "&gt;")
				.gsub("\n", "<br>")
		end

		def html(text, options)
			# like do nothing?
			text
			# use sanitizer in public security
		end

		def markdown(text, options)
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

		def textile(text, options)
			RedCloth.new(text).to_html
		end	
	end

	module Filter
		# well, shit, no libraries for language detection from the snippet
		# for now just markdown will work
		def highlight_source_code(source)
			formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
			formatter.format(lexer.lex(source))
		end
	end
end

