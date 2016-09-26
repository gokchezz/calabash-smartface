require 'erb'
require 'builder'
require 'cucumber/formatter/duration'
require 'cucumber/formatter/io'
require 'pathname'
require 'base64'
require 'mojo_magick'

module Cucumber
  module Formatter
    class Html

      # TODO: remove coupling to types
      AST_CLASSES = {
        Cucumber::Core::Ast::Scenario        => 'scenario',
        Cucumber::Core::Ast::ScenarioOutline => 'scenario outline'
      }
      AST_DATA_TABLE = LegacyApi::Ast::MultilineArg::DataTable

      include ERB::Util # for the #h method
      include Duration
      include Io

      def initialize(runtime, path_or_io, options)
        @io = ensure_io(path_or_io)
        @runtime = runtime
        @options = options
        @buffer = {}
        @builder = create_builder(@io)
        @feature_number = 0
        @scenario_number = 0
        @step_number = 0
        @header_red = nil
        @delayed_messages = []
        @img_id = 0
        @text_id = 0
        @inside_outline = false
        @previous_step_keyword = nil
        @previous_control_image = nil
      end

      def embed(src, mime_type, label)
        case(mime_type)
        when /^image\/(png|gif|jpg|jpeg)/
          unless File.file?(src) or src =~ /^data:image\/(png|gif|jpg|jpeg);base64,/
            type = mime_type =~ /;base[0-9]+$/ ? mime_type : mime_type + ";base64"
            src = "data:" + type + "," + src
          end
          embed_image(src, label)
        when /^text\/plain/
          embed_text(src, label)
        end
      end

      def embed_image(src, label)
        id = "img_#{@img_id}"
        control_id = "ctr_#{@img_id}"
        @img_id += 1
        if @io.respond_to?(:path) and File.file?(src)
          out_dir = Pathname.new(File.dirname(File.absolute_path(@io.path)))
          #src = Pathname.new(File.absolute_path(src)).relative_path_from(out_dir)
        end        
        @builder.span(:class => 'embed') do |pre|
          dimensions = MojoMagick::get_image_size(File.absolute_path(src))
          img_path = File.absolute_path(src)[0..File.absolute_path(src).index('.png')-1]
          if Dir[File.absolute_path(src)].length != 0
            MojoMagick::resize(File.absolute_path(src), "#{img_path}_embed.png", {:width=> dimensions[:width]*40/100, :height=>dimensions[:height]*40/100, :fill => true})
          else
            return
          end
          #f = File.binread(File.absolute_path(src))
          f = File.binread("#{img_path}_embed.png")
          encrypted_image = Base64.encode64(f).tr("\n", '')
          if (src.include? "_screenshot_") && (!@previous_control_image.nil?)
            control_image_name = @previous_control_image[0..@previous_control_image.length-5]
            control_image = "#{control_image_name}.png"
          else
            timestamp = Time.now.strftime('%d%b')
            device = src.split('/')[2]
            device = device[device.index('_')+1..device.length]
            #img_name = (src.split('/')[3])[0..(src.split('/')[3]).index(timestamp)-2]
            img_name = nil
            img_name_all = src.split('/')[src.split('/').length-1].split('_')
            img_name_all.each do |pc|
              if img_name.nil?
                img_name = pc
              elsif (!pc.include? timestamp) && (!pc.include? '.png')
                img_name = "#{img_name}_#{pc}"
              end
            end
            control_image_path = "#{File.absolute_path(src)[0..File.absolute_path(src).index('/screenshots')]}control_images"
            control_image_name = "#{control_image_path}/#{device}/#{img_name}"
            control_image = "#{control_image_name}.png"
            @previous_control_image = control_image
          end
          if Dir[control_image].length != 0
            MojoMagick::resize(control_image, "#{control_image_name}_embed.png", {:width=> dimensions[:width]*40/100, :height=>dimensions[:height]*40/100, :fill => true})
            control_f = File.binread("#{control_image_name}_embed.png")
            encrypted_control_image = Base64.encode64(control_f).tr("\n", '')
            pre << %{<table width="100%" align="center" border="0">
          <tr><td align="right" width="49%">Base Image</td><td width="2%"></td><td align="left" width="49%">Screenshot</td></tr>
          <tr><td align="right" width="49%">
              <a href="" onclick="img=document.getElementById('#{control_id}'); img.style.display = (img.style.display == 'none' ? 'block' : 'none');return false">
              <img height=120 src="data:image/png;base64,#{encrypted_control_image}"></a>
            </td><td width="2%"></td>
            <td align="left" width="49%">
              <a href="" onclick="img=document.getElementById('#{id}'); img.style.display = (img.style.display == 'none' ? 'block' : 'none');return false">
              <img height=120 src="data:image/png;base64,#{encrypted_image}"></a>
          </td>
          </tr>
          <tr><td align="right" width="49%"><img id="#{control_id}" style="display: none" src="data:image/png;base64,#{encrypted_control_image}"/></td> <td width="2%"></td>
            <td align="left" width="49%"><img id="#{id}" style="display: none" src="data:image/png;base64,#{encrypted_image}"/></td></tr>
          <tr><td align="right" width="49%">#{control_image}</td>
          <td width="2%"></td>
          <td align="left" width="49%">#{File.absolute_path(src)}</td></tr></table>
          }
          else
            pre << %{<table width="100%" align="center" border="0">
          <tr><td align="right" width="49%">No reference found</td><td width="2%"></td><td align="left" width="49%">Screenshot: #{File.absolute_path(src)}</td></tr></table>
          }
            #encrypted_control_image = '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'
          end
        end
      end

      def embed_text(src, label)
        id = "text_#{@text_id}"
        @text_id += 1
        @builder.span(:class => 'embed') do |pre|
          pre << %{<a id="#{id}" href="#{src}" title="#{label}">#{label}</a>}
        end
      end


      def before_features(features)
        @step_count = features && features.step_count || 0 #TODO: Make this work with core!

        # <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        @builder.declare!(
          :DOCTYPE,
          :html,
          :PUBLIC,
          '-//W3C//DTD XHTML 1.0 Strict//EN',
          'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'
        )

        @builder << '<html xmlns ="http://www.w3.org/1999/xhtml">'
          @builder.head do
          @builder.meta('http-equiv' => 'Content-Type', :content => 'text/html;charset=utf-8')
          @builder.title 'Cucumber'
          inline_css
          inline_js
        end
        @builder << '<body>'
        @builder << "<!-- Step count #{@step_count}-->"
        @builder << '<div class="cucumber">'
        @builder.div(:id => 'cucumber-header') do
          @builder.div(:id => 'label') do
            @builder.h1('Cucumber Features')
          end
          @builder.div(:id => 'summary') do
            @builder.p('',:id => 'totals')
            @builder.p('',:id => 'duration')
            @builder.div(:id => 'expand-collapse') do
              @builder.p('Expand All', :id => 'expander')
              @builder.p('Collapse All', :id => 'collapser')
            end
          end
        end
      end

      def after_features(features)
        print_stats(features)
        @builder << '</div>'
        @builder << '</body>'
        @builder << '</html>'
      end

      def before_feature(feature)
        @exceptions = []
        @builder << '<div class="feature">'
      end

      def after_feature(feature)
        @builder << '</div>'
      end

      def before_comment(comment)
        @builder << '<pre class="comment">'
      end

      def after_comment(comment)
        @builder << '</pre>'
      end

      def comment_line(comment_line)
        @builder.text!(comment_line)
        @builder.br
      end

      def after_tags(tags)
        @tag_spacer = nil
      end

      def tag_name(tag_name)
        @builder.text!(@tag_spacer) if @tag_spacer
        @tag_spacer = ' '
        @builder.span(tag_name, :class => 'tag')
      end

      def feature_name(keyword, name)
        lines = name.split(/\r?\n/)
        return if lines.empty?
        @builder.h2 do |h2|
          @builder.span(keyword + ': ' + lines[0], :class => 'val')
        end
        @builder.p(:class => 'narrative') do
          lines[1..-1].each do |line|
            @builder.text!(line.strip)
            @builder.br
          end
        end
      end

      def before_test_case(test_case)
        @previous_step_keyword = nil
      end

      def before_background(background)
        @in_background = true
        @builder << '<div class="background">'
      end

      def after_background(background)
        @in_background = nil
        @builder << '</div>'
      end

      def background_name(keyword, name, file_colon_line, source_indent)
        @listing_background = true
        @builder.h3(:id => "background_#{@scenario_number}") do |h3|
          @builder.span(keyword, :class => 'keyword')
          @builder.text!(' ')
          @builder.span(name, :class => 'val')
        end
      end

      def before_feature_element(feature_element)
        @scenario_number+=1
        @scenario_red = false
        css_class = AST_CLASSES[feature_element.class]
        @builder << "<div class='#{css_class}'>"
        @in_scenario_outline = feature_element.class == Cucumber::Core::Ast::ScenarioOutline
      end

      def after_feature_element(feature_element)
        unless @in_scenario_outline
          print_messages
          @builder << '</ol>'
        end
        @builder << '</div>'
        @in_scenario_outline = nil
      end

      def scenario_name(keyword, name, file_colon_line, source_indent)
        @builder.span(:class => 'scenario_file') do
          @builder << file_colon_line
        end
        @listing_background = false
        scenario_id = "scenario_#{@scenario_number}"
        if @inside_outline
          @outline_row += 1
          scenario_id += "_#{@outline_row}"
          @scenario_red = false
        end
        @builder.h3(:id => scenario_id) do
          @builder.span(keyword + ':', :class => 'keyword')
          @builder.text!(' ')
          @builder.span(name, :class => 'val')
        end
      end

      def before_outline_table(outline_table)
        @inside_outline = true
        @outline_row = 0
        @builder << '<table>'
      end

      def after_outline_table(outline_table)
        @builder << '</table>'
        @outline_row = nil
        @inside_outline = false
      end

      def before_examples(examples)
        @builder << '<div class="examples">'
      end

      def after_examples(examples)
        @builder << '</div>'
      end

      def examples_name(keyword, name)
        @builder.h4 do
          @builder.span(keyword, :class => 'keyword')
          @builder.text!(' ')
          @builder.span(name, :class => 'val')
        end
      end

      def before_steps(steps)
        @builder << '<ol>'
      end

      def after_steps(steps)
        print_messages
        @builder << '</ol>' if @in_background or @in_scenario_outline
      end

      def before_step(step)
        print_messages
        @step_id = step.dom_id
        @step_number += 1
        @step = step
      end

      def after_step(step)
        move_progress
      end

      def before_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
        @step_match = step_match
        @hide_this_step = false
        if exception
          if @exceptions.include?(exception)
            @hide_this_step = true
            return
          end
          @exceptions << exception
        end
        if status != :failed && @in_background ^ background
          @hide_this_step = true
          return
        end
        @status = status
        return if @hide_this_step
        set_scenario_color(status)
        @builder << "<li id='#{@step_id}' class='step #{status}'>"
      end

      def after_step_result(keyword, step_match, multiline_arg, status, exception, source_indent, background, file_colon_line)
        return if @hide_this_step
        # print snippet for undefined steps
        unless outline_step?(@step)
          keyword = @step.actual_keyword(@previous_step_keyword)
          @previous_step_keyword = keyword
        end
        if status == :undefined
          @builder.pre do |pre|
            # TODO: snippet text should be an event sent to the formatter so we don't 
            # have this couping to the runtime.
            pre << @runtime.snippet_text(keyword,step_match.instance_variable_get("@name") || '', @step.multiline_arg)
          end
        end
        @builder << '</li>'
        print_messages
      end

      def step_name(keyword, step_match, status, source_indent, background, file_colon_line)
        background_in_scenario = background && !@listing_background
        @skip_step = background_in_scenario

        unless @skip_step
          build_step(keyword, step_match, status)
        end
      end

      def exception(exception, status)
        return if @hide_this_step
        print_messages
        build_exception_detail(exception)
      end

      def extra_failure_content(file_colon_line)
        @snippet_extractor ||= SnippetExtractor.new
        "<pre class=\"ruby\"><code>#{@snippet_extractor.snippet(file_colon_line)}</code></pre>"
      end

      def before_multiline_arg(multiline_arg)
        return if @hide_this_step || @skip_step
        if AST_DATA_TABLE === multiline_arg
          @builder << '<table>'
        end
      end

      def after_multiline_arg(multiline_arg)
        return if @hide_this_step || @skip_step
        if AST_DATA_TABLE === multiline_arg
          @builder << '</table>'
        end
      end

      def doc_string(string)
        return if @hide_this_step
        @builder.pre(:class => 'val') do |pre|
          @builder << h(string).gsub("\n", '&#x000A;')
        end
      end

      def before_table_row(table_row)
        @row_id = table_row.dom_id
        @col_index = 0
        return if @hide_this_step
        @builder << "<tr class='step' id='#{@row_id}'>"
      end

      def after_table_row(table_row)
        return if @hide_this_step
        print_table_row_messages
        @builder << '</tr>'
        if table_row.exception
          @builder.tr do
            @builder.td(:colspan => @col_index.to_s, :class => 'failed') do
              @builder.pre do |pre|
                pre << h(format_exception(table_row.exception))
              end
            end
          end
          if table_row.exception.is_a? ::Cucumber::Pending
            set_scenario_color_pending
          else
            set_scenario_color_failed
          end
        end
        if @outline_row
          @outline_row += 1
        end
        @step_number += 1
        move_progress
      end

      def table_cell_value(value, status)
        return if @hide_this_step

        @cell_type = @outline_row == 0 ? :th : :td
        attributes = {:id => "#{@row_id}_#{@col_index}", :class => 'step'}
        attributes[:class] += " #{status}" if status
        build_cell(@cell_type, value, attributes)
        set_scenario_color(status) if @inside_outline
        @col_index += 1
      end

      def puts(message)
        @delayed_messages << message
        #@builder.pre(message, :class => 'message')
      end

      def print_messages
        return if @delayed_messages.empty?

        #@builder.ol do
          @delayed_messages.each do |ann|
            @builder.li(:class => 'step message') do
              @builder << ann
            end
          end
        #end
        empty_messages
      end

      def print_table_row_messages
        return if @delayed_messages.empty?

        @builder.td(:class => 'message') do
          @builder << @delayed_messages.join(", ")
        end
        empty_messages
      end

      def empty_messages
        @delayed_messages = []
      end

      def after_test_case(test_case, result)
        if result.failed? and not @scenario_red
          set_scenario_color_failed
        end
      end

      protected

      def build_exception_detail(exception)
        backtrace = Array.new
        @builder.div(:class => 'message') do
          message = exception.message
          if defined?(RAILS_ROOT) && message.include?('Exception caught')
            matches = message.match(/Showing <i>(.+)<\/i>(?:.+) #(\d+)/)
            backtrace += ["#{RAILS_ROOT}/#{matches[1]}:#{matches[2]}"] if matches
            matches = message.match(/<code>([^(\/)]+)<\//m)
            message = matches ? matches[1] : ""
          end

          unless exception.instance_of?(RuntimeError)
            message = "#{message} (#{exception.class})"
          end

          @builder.pre do
            @builder.text!(message)
          end
        end
        @builder.div(:class => 'backtrace') do
          @builder.pre do
            backtrace = exception.backtrace
            backtrace.delete_if { |x| x =~ /\/gems\/(cucumber|rspec)/ }
            @builder << backtrace_line(backtrace.join("\n"))
          end
        end
        extra = extra_failure_content(backtrace)
        @builder << extra unless extra == ""
      end

      def set_scenario_color(status)
        if status.nil? or status == :undefined or status == :pending
          set_scenario_color_pending
        end
        if status == :failed
          set_scenario_color_failed
        end
      end

      def set_scenario_color_failed
        @builder.script do
          @builder.text!("makeRed('cucumber-header');") unless @header_red
          @header_red = true
          scenario_or_background = @in_background ? "background" : "scenario"
          @builder.text!("makeRed('#{scenario_or_background}_#{@scenario_number}');") unless @scenario_red
          @scenario_red = true
          if @options[:expand] and @inside_outline
            @builder.text!("makeRed('#{scenario_or_background}_#{@scenario_number}_#{@outline_row}');")
          end
        end
      end

      def set_scenario_color_pending
        @builder.script do
          @builder.text!("makeYellow('cucumber-header');") unless @header_red
          scenario_or_background = @in_background ? "background" : "scenario"
          @builder.text!("makeYellow('#{scenario_or_background}_#{@scenario_number}');") unless @scenario_red
        end
      end

      def build_step(keyword, step_match, status)
        step_name = step_match.format_args(lambda{|param| %{<span class="param">#{param}</span>}})
        @builder.div(:class => 'step_name') do |div|
          @builder.span(keyword, :class => 'keyword')
          @builder.span(:class => 'step val') do |name|
            name << h(step_name).gsub(/&lt;span class=&quot;(.*?)&quot;&gt;/, '<span class="\1">').gsub(/&lt;\/span&gt;/, '</span>')
          end
        end

        step_file = step_match.file_colon_line
        step_file.gsub(/^([^:]*\.rb):(\d*)/) do
          if ENV['TM_PROJECT_DIRECTORY']
            step_file = "<a href=\"txmt://open?url=file://#{File.expand_path($1)}&line=#{$2}\">#{$1}:#{$2}</a> "
          end
        end

        @builder.div(:class => 'step_file') do |div|
          @builder.span do
            @builder << step_file
          end
        end
      end

      def build_cell(cell_type, value, attributes)
        @builder.__send__(cell_type, attributes) do
          @builder.div do
            @builder.span(value,:class => 'step param')
          end
        end
      end

      def inline_css
        @builder.style(:type => 'text/css') do
          @builder << File.read(File.dirname(__FILE__) + '/cucumber.css')
        end
      end

      def inline_js
        @builder.script(:type => 'text/javascript') do
          @builder << inline_jquery
          @builder << inline_js_content
        end
      end

      def inline_jquery
        File.read(File.dirname(__FILE__) + '/jquery-min.js')
      end

      def inline_js_content
        <<-EOF

  SCENARIOS = "h3[id^='scenario_'],h3[id^=background_]";

  $(document).ready(function() {
    $(SCENARIOS).css('cursor', 'pointer');
    $(SCENARIOS).click(function() {
      $(this).siblings().toggle(250);
    });

    $("#collapser").css('cursor', 'pointer');
    $("#collapser").click(function() {
      $(SCENARIOS).siblings().hide();
    });

    $("#expander").css('cursor', 'pointer');
    $("#expander").click(function() {
      $(SCENARIOS).siblings().show();
    });
  })

  function moveProgressBar(percentDone) {
    $("cucumber-header").css('width', percentDone +"%");
  }
  function makeRed(element_id) {
    $('#'+element_id).css('background', '#C40D0D');
    $('#'+element_id).css('color', '#FFFFFF');
  }
  function makeYellow(element_id) {
    $('#'+element_id).css('background', '#FAF834');
    $('#'+element_id).css('color', '#000000');
  }

        EOF
      end

      def move_progress
        @builder << " <script type=\"text/javascript\">moveProgressBar('#{percent_done}');</script>"
      end

      def percent_done
        result = 100.0
        if @step_count != 0
          result = ((@step_number).to_f / @step_count.to_f * 1000).to_i / 10.0
        end
        result
      end

      def format_exception(exception)
        (["#{exception.message}"] + exception.backtrace).join("\n")
      end

      def backtrace_line(line)
        line.gsub(/^([^:]*\.(?:rb|feature|haml)):(\d*).*$/) do
          if ENV['TM_PROJECT_DIRECTORY']
            "<a href=\"txmt://open?url=file://#{File.expand_path($1)}&line=#{$2}\">#{$1}:#{$2}</a> "
          else
            line
          end
        end
      end

      def print_stats(features)
        @builder <<  "<script type=\"text/javascript\">document.getElementById('duration').innerHTML = \"Finished in <strong>#{format_duration(features.duration)} seconds</strong>\";</script>"
        @builder <<  "<script type=\"text/javascript\">document.getElementById('totals').innerHTML = \"#{print_stat_string(features)}\";</script>"
      end

      def print_stat_string(features)
        string = String.new
        string << dump_count(@runtime.scenarios.length, "scenario")
        scenario_count = print_status_counts{|status| @runtime.scenarios(status)}
        string << scenario_count if scenario_count
        string << "<br />"
        string << dump_count(@runtime.steps.length, "step")
        step_count = print_status_counts{|status| @runtime.steps(status)}
        string << step_count if step_count
      end

      def print_status_counts
        counts = [:failed, :skipped, :undefined, :pending, :passed].map do |status|
          elements = yield status
          elements.any? ? "#{elements.length} #{status.to_s}" : nil
        end.compact
        return " (#{counts.join(', ')})" if counts.any?
      end

      def dump_count(count, what, state=nil)
        [count, state, "#{what}#{count == 1 ? '' : 's'}"].compact.join(" ")
      end

      def create_builder(io)
        Builder::XmlMarkup.new(:target => io, :indent => 0)
      end

      def outline_step?(step)
        not @step.step.respond_to?(:actual_keyword)
      end

      class SnippetExtractor #:nodoc:
        class NullConverter; def convert(code, pre); code; end; end #:nodoc:
        begin; require 'syntax/convertors/html'; @@converter = Syntax::Convertors::HTML.for_syntax "ruby"; rescue LoadError => e; @@converter = NullConverter.new; end

        def snippet(error)
          raw_code, line = snippet_for(error[0])
          highlighted = @@converter.convert(raw_code, false)
          highlighted << "\n<span class=\"comment\"># gem install syntax to get syntax highlighting</span>" if @@converter.is_a?(NullConverter)
          post_process(highlighted, line)
        end

        def snippet_for(error_line)
          if error_line =~ /(.*):(\d+)/
            file = $1
            line = $2.to_i
            [lines_around(file, line), line]
          else
            ["# Couldn't get snippet for #{error_line}", 1]
          end
        end

        def lines_around(file, line)
          if File.file?(file)
            begin
            lines = File.open(file).read.split("\n")
          rescue ArgumentError
            return "# Couldn't get snippet for #{file}"
          end
          min = [0, line-3].max
            max = [line+1, lines.length-1].min
            selected_lines = []
            selected_lines.join("\n")
            lines[min..max].join("\n")
          else
            "# Couldn't get snippet for #{file}"
          end
        end

        def post_process(highlighted, offending_line)
          new_lines = []
          highlighted.split("\n").each_with_index do |line, i|
            new_line = "<span class=\"linenum\">#{offending_line+i-2}</span>#{line}"
            new_line = "<span class=\"offending\">#{new_line}</span>" if i == 2
            new_lines << new_line
          end
          new_lines.join("\n")
        end

      end
    end
  end
end
