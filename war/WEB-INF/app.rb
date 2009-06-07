require 'rubygems'
require 'sinatra'
require 'appengine-apis/logger'
require 'lib/json'
require 'json'
require 'robot'
import org.json.JSONObject
 
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
end

post '/_wave/robot/:command' do
  logger.info "Input: " + request.env['rack.request.form_vars']
  json = JSON(request.env['rack.request.form_vars'])
  content_type 'application/json' 
  context = robot.run_command(params[:command], request.env['rack.request.form_vars')
  output = AbstractRobot.serialize_context(context)
  logger.info "Output: " + output
end

def robot
  Robot.from_yml('robot.yml')  
end

def logger
  AppEngine::Logger.new
end