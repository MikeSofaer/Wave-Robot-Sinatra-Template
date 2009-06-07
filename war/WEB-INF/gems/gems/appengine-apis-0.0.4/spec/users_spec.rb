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
require 'appengine-apis/users'

describe AppEngine::Users do
  before :all do
    AppEngine::Testing::install_api_stubs
  end
  
  before :each do
    @env = AppEngine::Testing::install_test_env
    @env.email = 'foo@example.com'
  end
  
  it "should have default auth_domain" do
    user = AppEngine::Users.current_user
    user.email.should == 'foo@example.com'
    user.auth_domain.should == 'gmail.com'
  end
  
  it 'should read auth_domain' do
    @env.auth_domain = 'example.com'
    AppEngine::Users.current_user.auth_domain.should == 'example.com'
  end
  
  it 'should read admin' do
    AppEngine::Users.admin?.should == false
    @env.admin = true
    AppEngine::Users.admin?.should == true
  end

  it 'should set logged_in?' do
    AppEngine::Users.logged_in?.should == true
    @env.email = nil
    AppEngine::Users.logged_in?.should == false
  end
  
  it 'should create urls' do
    login = AppEngine::Users.create_login_url('/foobar')
    logout = AppEngine::Users.create_logout_url('/foobaz')
    login.should =~ /foobar/
    logout.should =~ /foobaz/
  end
  
  it 'should support new without auth domain' do
    user = AppEngine::Users::User.new('foo@example.com')
    user.auth_domain.should == 'gmail.com'
  end
  
  
  it 'should support new with auth domain' do
    user = AppEngine::Users::User.new('foo@example.com', 'example.com')
    user.auth_domain.should == 'example.com'
  end
end
