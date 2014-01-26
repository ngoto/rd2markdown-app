=begin
= rd2markdown-lib.rb
=end

require "rd/rdvisitor"
require "rd/version"

module RD
  class RD2MarkdownVisitor < RDVisitor
    OUTPUT_SUFFIX = "markdown"
    INCLUDE_SUFFIX = ["markdown"]

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
      %Q[\n#{'#'*element.level} #{title.join("")}\n]
    end

    def apply_to_TextBlock(element, content)
      content.join("")
    end

    def apply_to_Verbatim(element)
      content = []
      element.each_line do |i|
        content.push(i)
      end
      %Q[<pre>#{content.join("").chomp}</pre>]
    end

    def apply_to_ItemList(element, items)
      "#{items.join("\n").chomp}\n"
    end

    def apply_to_EnumList(element, items)
      @enumcounter = 0
      "#{items.join("\n").chomp}\n"
    end

    def apply_to_DescList(element, items)
      "#{items.join("\n").chomp}\n"
    end

    def apply_to_MethodList(element, items)
      apply_to_DescList(element, items)
    end

    def apply_to_ItemListItem(element, content)
      %Q[* #{content.join("").chomp}]
    end

    def apply_to_EnumListItem(element, content)
      @enumcounter += 1
      %Q[#{@enumcounter}. #{content.join("").chomp}]
    end

    def apply_to_DescListItem(element, term, description)
      "#{Array(term).join("")}\n: #{description.join("")}\n"
    end

    def apply_to_MethodListItem(element, term, description)
      apply_to_DescListItem(element, term, description)
    end

    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end

    def apply_to_Emphasis(element, content)
      %Q[ *#{content.join("")}* ]
    end

    def apply_to_Code(element, content)
      %Q[ `#{content.join("")}` ]
    end

    def apply_to_Var(element, content)
      %Q[ `#{content.join("")}` ]
    end

    def apply_to_Keyboard(element, content)
      %Q[ `#{content.join("")}` ]
    end

    def apply_to_Index(element, content)
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
      if content.join("") == "<URL:#{element.label.url}>"
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
      # TODO: escape meta chars
      element
    end
  end
end

$Visitor_Class = RD::RD2MarkdownVisitor
