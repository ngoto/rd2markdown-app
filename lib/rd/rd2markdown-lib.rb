=begin
= rd2markdown-lib.rb
This file is same license of rdtool.
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
      content = content.join("")
      if (is_this_textblock_only_one_block_of_parent_listitem?(element) or
	  is_this_textblock_only_one_block_other_than_sublists_in_parent_listitem?(element))
	content.chomp
      else
        "#{content.rstrip}\n\n"
      end
    end

    def apply_to_Verbatim(element)
      lang=nil
      content = []
      element.each_line do |i|
        content.push(i)
        lang ||=
          case i
          when /^\s*\% /
            'sh'
          when /^\s*\\documentclass/
            'latex'
          when /require +["']/,
               /[a-z]+\.[a-z]+\.[a-z]+/,
               /[a-z]+\.[a-z][\_a-zA-Z0-9]*\(/,
               /[A-Z][\_A-Za-z0-9]+\:\:[A-Z][\_A-Za-z0-9]+/,
               /\]\.[a-z][\_a-zA-Z0-9]+/,
               /each +do/, /each \{/
            'ruby'
          end
      end

      %Q[```#{lang}\n#{content.join("").rstrip}\n```\n\n]
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

    def indent_for_list(s, flag_first, normal_prefix, indent_level = 1)
      # TODO: indent level should be counted by caller
      if /\A\`\`\`/ =~s && /\`\`\`\n\n\z/ =~ s then
        #first "\n" must be needed and
        #indent of each line must be exactly 4 spaces
        # Reference: https://gist.githubusercontent.com/clintel/1155906/raw/6b2a78696ff6b0b7222691c52fd0f3c6b98e3172/gistfile1.md
        "\n" + s.rstrip.gsub(/^/, '    ' * indent_level) + "\n"
      elsif flag_first then
        s.rstrip.gsub(/^(?!\A)/, normal_prefix)
      else
        s.rstrip.gsub(/^/, normal_prefix)
      end
    end
    private :indent_for_list

    def apply_to_ItemListItem(element, content)
      first = true
      a = content.map { |s|
        ret = indent_for_list(s, first, '   ')
        first = false
        ret
      }
      '* ' + a.join("\n")
    end

    def apply_to_EnumListItem(element, content)
      @enumcounter += 1
      prefix = %Q[#{@enumcounter}. ]
      indent = ' ' * prefix.size
      first = true
      a = content.map { |s|
        ret = indent_for_list(s, first, indent)
        first = false
        ret
      }
      prefix + a.join("\n")
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
      element = element.gsub(/([^\s])(\s*)[\r\n]+(\s*)([^\s])/) { |x|
        chrL = $1
        spcL = $2
        spcR = $3
        chrR = $4
        #$stderr.puts [ chrL, chrL.encoding, spcL, spcL.encoding, spcR, spcR.encoding, chrR, chrR.encoding ].inspect
        ret = if chrL.ord < 127 || chrR.ord < 127 then
                "#{chrL} #{chrR}"
              else
                "#{chrL}#{chrR}"
              end
        ret
      }
      meta_char_escape(element.delete("\r\n"))
    end

    def meta_char_escape(str)
      str.gsub(/[<>&`]/) {
        METACHAR[$&]
      }
    end
    private :meta_char_escape

    private

    def is_this_textblock_only_one_block_of_parent_listitem?(element)
      parent = element.parent
      (parent.is_a?(ItemListItem) or
       parent.is_a?(EnumListItem) or
       parent.is_a?(DescListItem) or
       parent.is_a?(MethodListItem)) and
	consist_of_one_textblock?(parent)
    end

    def is_this_textblock_only_one_block_other_than_sublists_in_parent_listitem?(element)
      parent = element.parent
      (parent.is_a?(ItemListItem) or
       parent.is_a?(EnumListItem) or
       parent.is_a?(DescListItem) or
       parent.is_a?(MethodListItem)) and
	consist_of_one_textblock_and_sublists(element.parent)
    end

    def consist_of_one_textblock_and_sublists(element)
      i = 0
      element.each_child do |child|
	if i == 0
	  return false unless child.is_a?(TextBlock)
	else
	  return false unless child.is_a?(List)
	end
	i += 1
      end
      return true
    end

    def consist_of_one_textblock?(listitem)
      listitem.children.size == 1 and listitem.children[0].is_a?(TextBlock)
    end

  end
end

$Visitor_Class = RD::RD2MarkdownVisitor
