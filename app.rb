require "sinatra/base"
require "better_errors"
require "binding_of_caller"
require "sinatra/reloader"
require "haml"
$LOAD_PATH << File.expand_path("lib")
require "rd/rd2markdown-lib"
require "rd/rdfmt"

class App < Sinatra::Base
  enable :inline_templates

  configure :development do
    use BetterErrors::Middleware
    BetterErrors.application_root = __dir__
    register Sinatra::Reloader
  end

  before do
    @title = "rd2markdown"
  end

  get "/" do
    @rd = <<-'RD'
= RD
(1) foo
(2) bar
    RD
    haml ""
  end

  post "/rd2markdown" do
    begin
      src = env["rack.request.form_hash"]["rd"].to_s
      unless /^=begin/ =~ src
        src = "=begin\n#{src}\n=end"
      end
      visitor = RD::RD2MarkdownVisitor.new
      tree = RD::RDTree.new(src)
      visitor.visit(tree).strip
    rescue => e
      "#{e.message}\n\n#{e.backtrace.join("\n")}"
    end
  end
end

App.run!

__END__
@@ layout
!!! 5
%html(lang="ja")
 %head
  %meta(charset="utf-8")
  %meta(name="viewport" content="width=device-width, initial-scale=1")
  %title= @title
  %link(rel="stylesheet" href="http://code.jquery.com/mobile/1.4.0/jquery.mobile-1.4.0.min.css")
  %script(src="http://code.jquery.com/jquery-1.9.1.min.js")
  %script(src="http://code.jquery.com/mobile/1.4.0/jquery.mobile-1.4.0.min.js")

  :javascript
   jQuery(function($) {
     var handler = function() {
       var src = $('#rd');
       $.ajax({
         url: "/rd2markdown",
         type: "POST",
         data: {
           rd: src.val()
         },
         error: function(xhr, status, error) {
           $('#markdown').val(error).change();
         },
         success: function(data, status, xhr) {
           $('#markdown').val(data).change();
         }
       });
       src.removeData('timerId');
     };
     $(document).on('keyup change input paste', '#rd', function() {
       var src, timerId;
       src = $(this);
       timerId = src.data('timerId');
       if (timerId) {
         src.removeData('timerId');
         clearTimeout(timerId);
       }
       src.data('timerId', setTimeout(handler, 1000));
     });
     handler();
   });
 %body.container
  %div(data-role="page")
   %div(data-role="header")
    %h1= @title
   %div(role="main" class="ui-content")
    %div= yield
    .ui-grid-a.ui-responsive
     .ui-block-a
      %form(method="post" role="form")
       %label(for="rd") Input (RD):
       %textarea.form-control(rows="10" id="rd" name="rd" placeholder="RD")= @rd
     .ui-block-b
      %form
       %label(for="markdown") Output (Markdown):
       %textarea.form-control(rows="10" id="markdown" name="markdown" placeholder="markdown")
