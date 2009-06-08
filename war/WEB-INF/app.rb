require 'rubygems'
require 'sinatra'
require 'appengine-apis/logger'
require 'json'
require 'robot'
 
get '/' do
  "I AM WAVE ROBOT! I sing like Frank on JRuby!"

end
get '/_wave/capabilities.xml' do
    content_type 'text/xml'
    robot.capabilities
end

post '/_wave/robot/jsonrpc' do
  logger.info "Input: " + request.env['rack.request.form_vars']
  json = JSON(request.env['rack.request.form_vars'])
  content_type 'application/json'
  context = robot.execute_json_rpc!(json)
  output = AbstractRobot.serialize_context(context)
  logger.info "Output: " + output
  output
end

post '/_wave/robot/:command' do
  logger.info "Input: " + request.env['rack.request.form_vars']
  json = JSON(request.env['rack.request.form_vars'])
  content_type 'application/json' 
  context = robot.run_command(params[:command].to_sym, json)
  output = AbstractRobot.serialize_context(context)
  logger.info "Output: " + output
  output
end

def robot
  Robot.new
end

def logger
  AppEngine::Logger.new
end