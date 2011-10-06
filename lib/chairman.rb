#!/usr/bin/env ruby

require 'eventmachine'
require 'restclient'
require 'json'

Services = JSON.parse(RestClient.get("http://0.0.0.0:3000/links.json"))

at_exit do
  Services.each do |service|
    puts "Deleting socket #{service['name']}.sok"
    File.delete "#{service['name']}.sok"
  end
end

module SocketServer
  def post_init
    puts "post init"
    @foo = rand(100)
  end

  def receive_data data
    puts "DATA: #{@foo} #{data.inspect}"
  end
end

EventMachine::run do
  Services.each do |service|
    puts "Making socket #{service['name']}.sok"
    EventMachine::start_unix_domain_server "#{service['name']}.sok", SocketServer
  end
end

