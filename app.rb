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

  post "/" do
    @rd = env["rack.request.form_hash"]["rd"].to_s
    visitor = RD::RD2MarkdownVisitor.new
    tree = RD::RDTree.new("=begin\n#{@rd}\n=end")
    @markdown = visitor.visit(tree).join("")
    haml ""
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
 %body.container
  %h1= @title
  %div= yield
  .row
   .col-md-6
    %form(method="post" role="form")
     .form-group
      %textarea.form-control(row="10" name="rd")= @rd
     %input.btn.btn-block.btn-default(type="submit")
   .col-md-6
    %pre.markdown&= @markdown
