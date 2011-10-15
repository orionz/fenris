module Chairman
  module Command
    def self.run(command, arg=nil, name=nil)
      client = Chairman::Client.new(ENV['CHAIRMAN_URL']);
      help = [ "Usage: chairman help\n",
               "       chairman info\n",
               "       chairman bind USER NAME\n",
               "       chairman add USER\n",
               "       chairman remove USER\n",
               "       chairman serve PORT\n",
               "       chairman connect" ]
      case command
        when "cert"
          puts client.cert.to_text
        when "bind"
          client.bind(arg,name)
        when "add"
          client.add(arg)
        when "remove"
          client.remove(arg)
        when "info"
          puts "INFO:"
          puts "     #{client.user["name"]} #{client.route}"
          unless client.consumers.empty?
            puts "CLIENTS:"
            client.consumers.each { |c| puts "    #{c["name"]} (#{c["binding"]})" }
          end
          unless client.providers.empty?
            puts "SERVICES:"
            client.providers.each { |c| puts "    #{c["binding"] || "unbound"} #{c["name"]} (#{c["provider"]}) #{c["ip"]} #{c["port"]}" }
          end
        when "serve"
          from = 10001
          to = arg.to_i
          Chairman::Base.serve(client, from, to) if to > 0
        when "connect"
          Chairman::Base.connect(client, arg, name)
        else
          puts command.inspect
          puts help
      end
      exit
    end
  end
end
