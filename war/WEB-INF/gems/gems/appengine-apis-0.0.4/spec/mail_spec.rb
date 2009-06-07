#!/usr/bin/ruby1.8 -w
#
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
#

require File.dirname(__FILE__) + '/spec_helper.rb'
require 'appengine-apis/apiproxy'
require 'appengine-apis/mail'

MailMessage = JavaUtilities.get_proxy_or_package_under_package(
  com.google.appengine.api.mail,
  'MailServicePb$MailMessage'
)

describe AppEngine::Mail do
  before :each do
    @delegate = mock_delegate
    AppEngine::ApiProxy.set_delegate(@delegate)
  end
  
  def should_send(message)
    should_make_call('Send', message)
  end
  
  def should_send_to_admins(message)
    should_make_call('SendToAdmins', message)
  end
  
  def should_make_call(call, message)
    @delegate.should_receive(:makeSyncCall).with(
      anything, 'mail', call, proto(MailMessage, message))
  end
  
  it "should send simple message" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?'
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?')
  end
  
  it "should support cc" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :cc => ['fred@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?'      
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?', :cc => 'fred@example.com')
  end
  
  it "should support bcc" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :bcc => ['fred@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?'      
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?', :bcc => 'fred@example.com')
  end
  
  it "should support multiple recipients" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com', 'fred@example.com'],
      :cc => ['bob@example.com', 'fred@example.com'],
      :bcc => ['bob@example.com', 'fred@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?'      
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', ['bob@example.com', 'fred@example.com'],
      'Howdy', 'Sup?',
      :cc => ['bob@example.com', 'fred@example.com'],
      :bcc => ['bob@example.com', 'fred@example.com'])    
  end
  
  it "should support no to" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => [],
      :bcc => ['fred@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?'      
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', nil,
      'Howdy', 'Sup?', :bcc => 'fred@example.com')
  end
  
  it "should support html" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?', 
      :html_body => '<h1>Sup?</h1>',
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?', :html => '<h1>Sup?</h1>')
  end
  
  it "should support html only" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :subject => 'Howdy',
      :html_body => '<h1>Sup?</h1>',
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', nil, :html => '<h1>Sup?</h1>')
  end
  
  it "should support attachments hash" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?',
      :attachment => [
        {:file_name => 'foo.gif', :data => 'foo'},
        ]
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?', :attachments => {'foo.gif' => 'foo'})
  end
  
  it "should support attachments list" do
    should_send({
      :sender => 'ribrdb@example.com',
      :to => ['bob@example.com'],
      :subject => 'Howdy',
      :text_body => 'Sup?',
      :attachment => [
        {:file_name => 'foo.gif', :data => 'foo1'},
        {:file_name => 'foo.gif', :data => 'foo2'},
        ]
    })
    AppEngine::Mail.send(
      'ribrdb@example.com', 'bob@example.com',
      'Howdy', 'Sup?',
      :attachments => [['foo.gif', 'foo1'], ['foo.gif', 'foo2']])
  end
  
  it "should support sending to admins" do
    should_send_to_admins({
      :sender => 'ribrdb@example.com',
      :subject => 'Howdy',
      :text_body => 'Sup?'
    })
    AppEngine::Mail.send_to_admins('ribrdb@example.com', 'Howdy', 'Sup?')
  end
end
