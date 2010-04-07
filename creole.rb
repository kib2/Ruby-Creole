#!/usr/bin/ruby
# coding: utf-8

#
# Goal:          Creole 1.0 markup parser (http://www.wikicreole.org/)
# Author:        Kibleur Christophe
# Mail:          kibleur.christophe@gmail.com
# Version:       1.0
# First release: jan 27, 2010
#

require 'cgi'

# If you also need Prism inside to highlight your source-code
# you'll have to uncomment the following and put the prism dir.
# inside prism/ :
# Also uncomment what's in 'code_end' method
# require File.dirname(__FILE__) + '/prism/Prism'

#==============================================================================
#                            HtmlFormatter Class
#==============================================================================
class CreoleHtmlFormatter
  # The formatter is used by the wikiparser to render
  # a line of text to a given format
  attr_accessor :parent, :tpl
  attr_reader :parent, :tpl

  def initialize
    @parent = nil
    @tpl = nil
  end
  
  # === BLOCKS
  def close_tag(r)
    if @parent.env == "list"
      return list_end(r)
    elsif @parent.env == "code"
      return code_end(r)
    elsif @parent.env == "table"
      return table_end(r)
    else
      return para_end(r)     
    end
    @parent.out = []
    @parent.env = ''
    @parent.list_env = []
  end
  
  # HEADERS
  def title(r)
    lev = r[1].length.to_s
    @parent.stack << "<h#{lev}>" + r[2].gsub(/=/,"").rstrip + "</h#{lev}>"
    true
  end
  
  # PARAGRAPHS
  def para_end(r)
    k = @parent.out.join("\n").rstrip
    if k != ""
      k = @parent.inline(CGI.escapeHTML(k), @parent.inline_states[-1])
      @parent.stack << "<p>#{k}</p>"
      @parent.out = []
    end
    true
  end
  
  # === SOURCE CODE
  def code_start(r)
    close_tag(r)
    @parent.env = "code"
    @parent.lang = r[1]
    true
  end
  
  def code_false(r)
    @parent.out << '}}}'
    true
  end
  
  def code_end(r)
    k = ""
    
    # If you want Prism inside comment the 2 following lines...
    res = @parent.out.join("\n")
    @parent.stack << "<pre>#{res}</pre>"

    # ... Then uncomment these ones:
    ## if ['rb','js','xml','falcon','clojure'].include?(@parent.lang)
    ##   formatter = HtmlFormatter.new()
    ##   h = HL.new(formatter, @parent.lang) ##"rb")
    ##   k = h.from_list(@parent.out) #h.highlight(@parent.out)
    ## else
    ##   res = @parent.out.join("\n")
    ##   @parent.stack << "<pre class=\"code\">#{res}</pre>"
    ## end
    
    #k = @parent.out.join("\n").rstrip
    if k != ""
      @parent.stack << "<pre class=\"code\">#{k}</pre>"
    end
    @parent.out = []
    @parent.lang = ""
    @parent.env = ""

    true
  end
  
  # === TABLES
  def table_start(r)
    close_tag(r)
    @parent.env = "table"
    heads = r[1].gsub(/[=]/,"")
    @parent.out << heads
    true
  end
  
  def table_inside(r)
    @parent.out << r[1]
    true
  end

  def table_end(r)
    out = []
    out << "<table>"
    i = 0
    rows = @parent.out
    
    rows.each_with_index do |row,idx|
        ## just to have different background colors for odd/even rows
        if i%2 == 0
            out << "<tr>"
        else
            out << "<tr class=\"odd\">"
        end
  
        cols = row.split("|")

        cols.each do |col|
            if idx == 0
                k = @parent.inline(CGI.escapeHTML( col.strip ), @parent.inline_states[-1])
                out << "    <th>#{k}</th>"
            else
                k = @parent.inline(CGI.escapeHTML( col.strip ), @parent.inline_states[-1])
                out << "    <td>#{k}</td>"
            end
        end
        out << "</tr>"
        i += 1
    end
    out << "</table>"
    @parent.out = []
    @parent.env = ''
    @parent.stack << out.join("\n")
    false
  end

  # === LISTS
  def list_start(r)
    close_tag(r)
    @parent.env = "list"
    lev, type, contents = r[1].length, r[2], r[3]
    @parent.list_env << [lev, type, contents]
    true
  end
  
  def list_inside(r)
    @parent.list_env[-1][2] += ("\n" + @parent.out.join("\n")).rstrip
    @parent.out = []
    lev, type, contents = r[1].length, r[2], r[3]
    @parent.list_env << [lev, type, contents]
    true
  end
  
  def list_end(r)
    if @parent.list_env.length > 0
      if @parent.out
        @parent.list_env[-1][2] +=  ("\n" + @parent.out.join("\n")).rstrip 
        @parent.out = []
      end
      @parent.stack << list_in_xhtml(@parent.list_env,true,true)
      @parent.list_env = []
      @parent.env = ""
    end
    true
  end
  
  def list_in_xhtml(items, want_escape, want_inline)
      # items must be a list ie: [level,type,contents]
      #   where :
      #     level is an int
      #     list-type is "*" or "#"
      #     contents is a string 
      # wantEsc    : false or true
      # wantInline : false or true 
      out = []
      cumul = 1
      old_lev = nil
      stack = []
  
      def indent(c)
          "  "*(c.abs)
      end
  
      # handles list types (normal, enumerated)
      def lt(c)
          if c == "*"
              ["<ul>", "</ul>"]
          else
              ["<ol>", "</ol>"]
          end
      end
  
      op_li = "<li>"
      cl_li = "</li>"
  
      first_lev = items[0][0]
      
      # A little fix if the list starts with a level > 1
      if first_lev != 1
          items2 = []
          for lev,list_type,content in items
               items2 <<  [lev-first_lev+1,list_type,content]
          end
          items = items2
      end
  
      items.each do |lev,list_type,cont|
      #for lev,list_type,content in items

          if want_escape
              cont = CGI.escapeHTML(cont)
          end
  
          if want_inline
              cont = @parent.inline( cont, @parent.inline_states[-1] )
          else
              cont = @parent.inline( cont, @parent.inline_states[-1] ) #content
          end

          if not old_lev
              out << indent(cumul-1) + lt(list_type)[0]
              stack.push( list_type )
              out << op_li + cont
          elsif lev == old_lev
              out[-1] += cl_li
              out << indent(cumul) + op_li + cont
          elsif lev > old_lev
              diff = lev - old_lev
              cumul += diff
              (0..diff-1).each { |k|
                  out << indent(cumul+k) + lt(list_type)[0]
                  stack.push( list_type )
              }
              out << indent(cumul) +  op_li + cont
          elsif lev < old_lev
              diff = old_lev - lev
              cumul -= diff
  
              out[-1] += cl_li
              (0..diff-1).each { |k|
                  a = stack.pop
                  out << indent(cumul+k+1) + lt(a)[1]
                  out << indent(cumul+k) + cl_li
                  }
              out << indent(cumul) + op_li + cont
          end
  
          old_lev = lev
      end
  
      out[-1] += cl_li
      (0..cumul-1).each { |k|
          a = stack.pop
          if a
              out << indent(cumul - k - 1) + lt(a)[1]
              out << indent(cumul - k - 1) + cl_li
          end
          }
      out[-1] = ""
      out.join("\n")
  end

end

#==============================================================================
#                            WikiParser Class
#==============================================================================

class Creole
  attr_accessor :formatter, :language, :all_rules, :states, :stack, 
                :num_of_lines, :out, :inline_states, :env, :list_env,
                :lang
  attr_reader :formatter, :language, :all_rules, :states, :stack, 
              :num_of_lines, :out, :inline_states, :env, :list_env,
              :lang

  def initialize(formatter = CreoleHtmlFormatter.new(), language = 'rb', sitelink = 'http://kib2.free.fr')
    @formatter        = formatter
    @formatter.parent = self
    @language         = language
    @sitelink         = sitelink
    @all_rules        = load_block_rules()
    @states           = [:root] # will be filled in load_syntax_def
    @stack            = []
    @inline_states    = [:root]
    @out              = []
    @lang             = ""
    @list_env = []
    @env = ""
    
    # == INLINE RULES
    @inline_rules = {
    # The root state
    :root => [
      [/[~]{2}/, '~', nil], # replace "~~" with "~"
      [/[~]/, '', :esc], # goto escape state
      [/[-]{4,}/, '<hr/>', nil],
      [/\\\\/, "<br />", nil],
      [/[*]{2}/ , "<strong>", :bold], #(?<!~)
      [/[\/]{2}/, '<em>', :italic], #(?<!~)
      [/\{\{\{/, '<tt>', :nowiki],
      # links
      [/(\b(?:(?:https?|ftp):\/\/|mailto:)\S*[^\s!"\',.:;?])/, "<a href=\"\\0\">\\0</a>", nil],
      [/\[\[(http:\/\/[^|]+)\|(.+)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
      [/\[\[([^|]+)\]\]/, "<a href=\"#{sitelink}/\\1\">\\1</a>", nil],
      [/\[\[([^|]+)\|(.*)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
      # images
      [/[{]{2}(.*?)\|(.*?)[}]{2}/, "<img src=\"\\1\" alt=\"\\2\" />", nil],
    ],
    :esc => [
      [/[~]/, '~', '#pop'],
      [/[*]{2}/ , '**', '#pop'],
      [/[\/]{2}/, '//', '#pop'],
      [/\{\{\{/,  '{{{', '#pop'],
      [/[-]{4,}/, '----', '#pop'],
      [/\\\\/,    '\\', '#pop'],
    ],
    # Nowiki State
    :nowiki => [
      [/(?<!~)\}\}\}/, '</tt>' , '#pop']
    ],
    # Bold state
    :bold => [
      [/[~]{2}/, '~', nil], # replace "~~" with "~"
      [/[~]/, '', :esc], # goto escape state
      [/[*]{2}/, '</strong>', "#pop"], 
      [/[\/]{2}/, '<em>', :italic], #(?<!~)
      # links
      [/(\b(?:(?:https?|ftp):\/\/|mailto:)\S*[^\s!"\',.:;?])/, "<a href=\"\\0\">\\0</a>", nil],
      [/\[\[(http:\/\/[^|]+)\|(.*)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
      [/\[\[([^|]+)\]\]/, "<a href=\"#{@sitelink}/\\1\">\\1</a>", nil],
      [/\[\[([^|]+)\|(.*)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
    ],
    # Italic State
    :italic => [
      [/[~]{2}/, '~', nil], # replace "~~" with "~"
      [/[~]/, '', :esc], # goto escape state
      [/[\/]{2}/, '</em>', "#pop"], #(?<!~)
      [/[*]{2}/ , "<strong>", :bold], #(?<!~)
      # links
      [/(\b(?:(?:https?|ftp):\/\/|mailto:)\S*[^\s!"\',.:;?])/, "<a href=\"\\0\">\\0</a>", nil],
      [/\[\[(http:\/\/[^|]+)\|(.*)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
      [/\[\[([^|]+)\]\]/, "<a href=\"#{@sitelink}/\\1\">\\1</a>", nil],
      [/\[\[([^|]+)\|(.*)\]\]/, "<a href=\"\\1\">\\2</a>", nil],
    ]
  }
  end

  def load_block_rules()
    # In Ruby, the caret and dollar always match before and after newlines. 
    # Ruby does not have a modifier to change this. Use \A and \Z to match 
    # at the start or the end of the string.
    @all_rules = {
      # The root state
      :root => [
        [/\A([=]+)\s*(.+)/ , "title"],
        [/\A(\s|\t)*$/, 'para_end'],
        [/\A[{]{3}\s*(\w+)?/, 'code_start', 'source'],
        [/\A\s*(([*#]){1,5})\s*(.*?)\s*\z/, 'list_start', 'list'],
        [/\A[|](.*?)[|]\s*$\z/, 'table_start', 'table']
      ],
      # Source state
      :source => [
        [/\A~[}]{3}/, 'code_false'],
        [/\A[}]{3}/, 'code_end', "#pop"],
      ],
      # List State
      :list => [
        [/\A\s*(([*#]){1,5})\s*(.*?)\s*\z/, 'list_inside'],
        [/\A(\s|\t)*$/, 'list_end', "#pop"]
      ],    
      # Table State
      :table => [
        [/\A[|](.*?)[|]\s*$\z/, 'table_inside'],
        [/\A(\s|\t)*$/, 'table_end', "#pop"]
      ]
    }
  end

  # ===========================
  #      INLINE FORMATTING
  # 1. check if the rule match
  # 2. check if ~ not present before
  # 3. format the string
  # ===========================
  def inline(text, initstate)
    closeInline(_inline(text, initstate) )
  end
  
  def find_nearest_match(text, initstate)
    if text == ""
      return nil
    end
    
    matched = false
    smallest = text.length
    res = false

    @inline_rules[initstate].each do |regex, format, newstate|
      if md = regex.match(text)
        if md.begin(0) < smallest
          matched = true
          res = [md, format, newstate, regex]
          smallest = md.begin(0)
        end
      end  
    end
    
    res 
  end
    
  def _inline(text, initstate)
    out = []
    postm = ""
    r = find_nearest_match(text, initstate)
    while r
      nm,format,newstate,regex = r[0], r[1], r[2], r[3]

      prem = nm.pre_match
      postm = nm.post_match
      
      if newstate == nil
          out << prem + nm[0].sub(regex, format)
          k = @inline_states[-1]
      elsif newstate == "#popnil"        
          if @inline_states.length >= 1
            @inline_states.pop
            k = @inline_states[-1]
          end
          out << prem + nm[0].sub(regex, format)
      elsif newstate == "#pop"
          if @inline_states.length >= 1
            @inline_states.pop
            k = @inline_states[-1]
          end
          out << prem + format
      else
          @inline_states << newstate unless @inline_states[-1] == newstate
          k = @inline_states[-1]
          out << prem + format
      end

      r = find_nearest_match(postm, k)
    end
    out << postm
    res = out.join("")
    if res == ""
      text + postm
    else
      res
    end

  end
  
  def closeInline(text)
    @inline_states.reverse_each do |el|
      if el == :bold
        text += "</strong>"
      elsif el == :italic
        text += "</em>"
      else
        break
      end
    end
    @inline_states = [:root]
    text
  end

  # ===========================
  #      MAIN PARSE METHOD
  # ===========================
  def gen_output(line)
    res = false 
    @all_rules[@states[-1]].each do |rule|
      if md = rule[0].match(line)
        # calls the formatter method dynamically 
        # with the regexp as argument
        res = @formatter.send(rule[1].to_sym, md)
        if rule.length > 2
          if rule[2] == "#pop" # and @states.size > 1
            @states.pop
          else 
            @states << rule[2].to_sym
          end
        end 
        break
      end
    end # all_rules
    # The formatter callbacks decides 
    # to take the parsed line into account or not
    # set it to 'true' if you want to handle it yourself
    # inside the callback
    @out << line.rstrip unless res 
  end
  
  def fromString(text)
    # .gsub("\r\n","\n")
    text.lines.each do |line|
      gen_output(line) 
    end # open
    @formatter.close_tag(nil)
    @stack.join("\n\n")
  end
  
  def fromFile(filename)
    open(filename).each_with_index do |line, linum|
      gen_output(line)
    end # open
    @formatter.close_tag(nil)
  end # parse
  
end