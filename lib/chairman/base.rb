require 'eventmachine'
require 'restclient'
require 'json'
require 'ostruct'

module Chairman
  module ClientSocket
    def post_init
      @foo = rand(100)
    end

    def receive_data data
    end
  end
end

module ProxyConnection
  def initialize(client)
    @client = client
  end

  def post_init
    @client.enable_proxy self
  end

  def proxy_target_unbound
    close_connection
  end

  def unbind
    @client.close_connection_after_writing
  end
end

module Chairman
  module ServiceSocket
    def initialize(port) 
      @port = port
      @q = []
    end

    def enable_proxy(dest)
      @q.each { |d| dest.send_data d }
      @q = []
      @target = dest
      EventMachine::enable_proxy dest, self
    end

    def post_init
      EventMachine::connect "0.0.0.0", @port, ProxyConnection, self
    end

    def receive_data data
      if @target
        @target.send_data data
      else
        @q << data
      end
    end
  end
end

module Chairman
  module Base
    extend self

    def serve(from, to)
      EventMachine::run do
        RestClient.put("http://0.0.0.0:3000/users/2.json", { :user => { :ip => "0.0.0.0", :port => from } });
        puts "Serving port #{to} on #{from}"
        EventMachine::start_server "0.0.0.0", from, Chairman::ServiceSocket, to
      end
    end

    def connect(dir)
      Dir.chdir(dir)

      at_exit do
        services.each do |service|
          puts "Deleting socket '#{service.name}'."
          File.delete service.name if File.exists? service.name
        end
      end

      EventMachine::run do
        services.each do |service|
          puts "Making socket '#{service.name}'."
          EventMachine::start_unix_domain_server service.name, Chairman::ClientSocket, service
        end
      end
    end

    def services
      @services ||= JSON.parse(RestClient.get("http://0.0.0.0:3000/links.json")).map { |s| OpenStruct.new s }
    end
  end
end


