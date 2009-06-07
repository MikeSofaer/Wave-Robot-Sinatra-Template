require 'rubygems'
require 'app'
 
set :environment, :development
set :run, false
 
run Sinatra::Application
