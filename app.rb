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
  enable :logging

  configure :development do
    use BetterErrors::Middleware
    BetterErrors.application_root = __dir__
    register Sinatra::Reloader
  end

  before do
    @title = "rd2markdown"
  end

  get "/" do
    haml ""
  end

  post "/rd2markdown" do
    begin
      src = env["rack.request.form_hash"]["rd"].to_s
      visitor = RD::RD2MarkdownVisitor.new
      tree = RD::RDTree.new("=begin\n#{src}\n=end")
      visitor.visit(tree).join("").strip
    rescue => e
      e.message
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
  %meta(name="viewport" content="width=device-width, initial-scale=1.0")
  %title= @title
  %link(rel="stylesheet" href="//netdna.bootstrapcdn.com/bootswatch/3.0.3/united/bootstrap.min.css")
  %script(src="//code.jquery.com/jquery-2.1.0.min.js")
  :javascript
   jQuery(function($) {
     jQuery.fn.autogrow = function(options) {
       var handler, self, settings, timerId;
       settings = $.extend({
         extraLineHeight: 15,
         timeoutBuffer: 100
       }, options);
       self = this;
       timerId = self.removeData('timerId');
       if (timerId) {
         clearTimeout(timerId);
       }
       handler = function() {
         self.each(function(i, e) {
           var clientHeight, scrollHeight;
           scrollHeight = e.scrollHeight;
           clientHeight = e.clientHeight;
           if (clientHeight < scrollHeight) {
             return $(e).height(scrollHeight + settings.extraLineHeight);
           }
         });
         return self.removeData('timerId');
       };
       return self.data('timerId', setTimeout(handler, settings.timeoutBuffer));
     };
     $(document).on('keyup.autogrow change.autogrow input.autogrow paste.autogrow', 'textarea', function() {
       return $(this).autogrow();
     });
     $('textarea').autogrow();

     $(document).on('keyup change input paste', '#rd', function() {
       var handler, self, timerId;
       self = $(this);
       console.log(self)
       timerId = self.removeData('timerId');
       if (timerId) {
         clearTimeout(timerId);
       }
       handler = function() {
         $.ajax({
           url: "/rd2markdown",
           type: "POST",
           data: {
             rd: self.val()
           },
           error: function(xhr, status, error) {
             $('#markdown').val(error).change();
           },
           success: function(data, status, xhr) {
             $('#markdown').val(data).change();
           }
         });
         self.removeData('timerId');
       };
       self.data('timerId', setTimeout(handler, 1000));
     });

   });
 %body.container
  %h1= @title
  %div= yield
  .row
   .col-md-6
    %form(method="post" role="form")
     .form-group
      %textarea.form-control(rows="10" id="rd" name="rd")= @rd
   .col-md-6
    %form
     .form-group
      %textarea.form-control#markdown(readonly)
