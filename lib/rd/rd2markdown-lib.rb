=begin
= rd2markdown-lib.rb
=end

require "rd/rdvisitor"
require "rd/version"

module RD
  class RD2MarkdownVisitor < RDVisitor
    OUTPUT_SUFFIX = "markdown"
    INCLUDE_SUFFIX = ["markdown"]

    METACHAR = { "<" => "&lt;", ">" => "&gt;", "&" => "&amp;", '`' => "&#96;" }

    def initialize
      @enumcounter = 0
    end

    def visit(tree)
      prepare_labels(tree, "label-")
      super(tree).join("")
    end

    def apply_to_DocumentElement(element, content)
      content
    end

    def apply_to_Headline(element, title)
      %Q[#{'#'*element.level} #{title.join("").rstrip}\n\n]
    end

    def apply_to_TextBlock(element, content)
      "#{content.join("").rstrip}\n\n"
    end

    def apply_to_Verbatim(element)
      content = []
      element.each_line do |i|
        content.push(i)
      end
      %Q[<pre>#{content.join("").rstrip}</pre>\n\n]
    end

    def apply_to_ItemList(element, items)
      "#{items.join("\n").rstrip}\n\n"
    end

    def apply_to_EnumList(element, items)
      # FIXME: broken counter in nested enum list
      @enumcounter = 0
      "#{items.join("\n").rstrip}\n\n"
    end

    def apply_to_DescList(element, items)
      %Q[<dl>\n#{items.map{|s| s.rstrip }.join("\n")}</dl>\n\n]
    end

    def apply_to_MethodList(element, items)
      %Q[<dl>\n#{items.map{|s| s.rstrip }.join("\n")}</dl>\n\n]
    end

    def apply_to_ItemListItem(element, content)
      '* ' + content.map{|s| s.rstrip }.join("\n").gsub(/^(?!\A)/, '  ')
    end

    def apply_to_EnumListItem(element, content)
      @enumcounter += 1
      prefix = %Q[#{@enumcounter}. ]
      indent = ' ' * prefix.size
      prefix + content.map{|s| s.rstrip }.join("\n").gsub(/^(?!\A)/, indent)
    end

    def apply_to_DescListItem(element, term, description)
      if description.empty?
        %Q[<dt>#{Array(term).join("")}</dt>\n]
      else
        %Q[<dt>#{Array(term).join("")}</dt>\n<dd>#{description.join("").rstrip}</dd>\n]
      end
    end

    def apply_to_MethodListItem(element, term, description)
      # TODO: see parse_method in lib/rd/rd2html-lib.rb
      apply_to_DescListItem(element, term, description)
    end

    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end

    def apply_to_Emphasis(element, content)
      %Q[<em>#{content.join("")}</em>]
    end

    def apply_to_Code(element, content)
      %Q[<code>#{content.join("")}</code>]
    end

    def apply_to_Var(element, content)
      %Q[<var>#{content.join("")}</var>]
    end

    def apply_to_Keyboard(element, content)
      %Q[<kbd>#{content.join("")}</kbd>]
    end

    def apply_to_Index(element, content)
      # TODO: ignored
      content.join("")
    end

    def apply_to_Reference(element, content)
      case element.label
      when Reference::URL
        apply_to_RefToURL(element, content)
      when Reference::RDLabel
        if element.label.filename
          apply_to_RefToOtherFile(element, content)
        else
          apply_to_RefToElement(element, content)
        end
      end
    end

    def apply_to_RefToElement(element, content)
      content = content.join("")
      if anchor = refer(element)
        content = content.sub(/^function#/, "")
        %Q<[#{content}](#{anchor})>
      else
        content
      end
    end

    def apply_to_RefToOtherFile(element, content)
      content = content.join("")
      anchor = refer_external(element)
      if anchor
        %Q<[#{content}](#{filename}\##{anchor})>
      else
        %Q<[#{content}](#{filename})>
      end
    end

    def apply_to_RefToURL(element, content)
      if content.join("") == meta_char_escape("<URL:#{element.label.url}>")
        element.label.url
      else
        %Q<[#{content.join("")}](#{element.label.url})>
      end
    end

    def apply_to_Footnote(element, content)
      "FIXME"
    end

    def apply_to_Verb(element)
      apply_to_String(element.content)
    end

    def apply_to_String(element)
      meta_char_escape(element.delete("\r\n"))
    end

    def meta_char_escape(str)
      str.gsub(/[<>&`]/) {
        METACHAR[$&]
      }
    end
    private :meta_char_escape
  end
end

$Visitor_Class = RD::RD2MarkdownVisitor
