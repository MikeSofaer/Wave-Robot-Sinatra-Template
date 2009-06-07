# Copyright:: Copyright 2009 Google Inc.
# Original Author:: Ryan Brown (mailto:ribrdb@google.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require File.dirname(__FILE__) + '/spec_helper.rb'
require 'appengine-apis/logger'

describe AppEngine::Logger do
  before :all do
    class << AppEngine::ApiProxy
      alias log_without_intercept log
      def log(*args)
        @logs << args
      end
      
      def clear_logs
        @logs = []
      end

      attr_reader :logs
    end
  end
  
  before :each do
    @logger = AppEngine::Logger.new
    AppEngine::ApiProxy.clear_logs
  end
  
  after :all do
    class << AppEngine::ApiProxy
      alias log log_without_intercept
    end
  end
  
  it "should log" do
    @logger.warn "foobar"
    AppEngine::ApiProxy.logs.should == [
      [AppEngine::ApiProxy::LogRecord::Level::warn, "foobar"]]
  end
  
  it "should obey level" do
    @logger.level = Logger::INFO
    @logger.debug "debug"
    @logger.info "info"
    @logger.fatal "fatal"
    AppEngine::ApiProxy.logs.should == [
      [AppEngine::ApiProxy::LogRecord::Level::info, "info"],
      [AppEngine::ApiProxy::LogRecord::Level::fatal, "fatal"],
    ]
  end
  
  it "should support <<" do
    @logger << "flowers"
    AppEngine::ApiProxy.logs.should == [
      [AppEngine::ApiProxy::LogRecord::Level::info, "flowers"]]    
  end
end