module Fenris
  module Command
    def self.run(command, *args)
      arg, name = args
      begin
        url = URI.parse(ENV['FENRIS_URL'] || 'https://broker.fenris.cc/')
        url.user ||= ENV['FENRIS_USER']
        url.password ||= ENV['FENRIS_AUTHKEY']
        client = Fenris::Client.new url
        help = [ "Usage: fenris help\n",
                 "       fenris info\n",
                 "       fenris bind PROVIDER BINDING\n",
                 "       fenris useradd NAME\n",
                 "       fenris userdel NAME\n",
                 "       fenris users\n",
                 "       fenris rekey\n",
                 "       fenris add CONSUMER\n",
                 "       fenris remove CONSUMER\n",
                 "       fenris exec COMMAND\n",
                 "       fenris provide BINDING\n",
                 "       fenris consume [ USER [ BINDING ] ]" ]
        case command
          when "users"
            client.users.each do |u|
              puts u["name"]
            end
          when "userdel"
            client.userdel(arg)
            puts "ok"
          when "useradd"
            new_user = client.useradd(arg)
            puts "New user created"
            puts "export FENRIS_USER='#{new_user["name"]}'"
            puts "export FENRIS_AUTHKEY='#{new_user["authkey"]}'"
          when "rekey"
            newkey = client.rekey
            puts "New Key Assigned:"
            puts "export FENRIS_AUTHKEY='#{newkey}'"
          when "cert"
            puts client.cert.to_text
          when "bind"
            client.bind(arg,name)
          when "add"
            client.add(arg)
          when "remove"
            client.remove(arg)
          when "info"
            printf "INFO:\n"
            printf "  %s\n", client.user["name"]
            unless client.users.empty?
              puts "SUBACCOUNTS:"
              client.users.each { |c| printf "  %-20s\n", c["name"] }
            end
            unless client.consumers.empty?
              puts "CLIENTS:"
              client.consumers.each { |c| printf "  %-20s\n", c["name"] }
            end
            unless client.providers.empty?
              puts "SERVICES:"
              client.providers.each { |c| printf "  %-20s  %s\n", c["name"], c["location"] }
            end
          when "provide"
            external = "#{Socket.gethostname}:#{10001}"
            internal = arg
            Fenris::Base.provide(client, external, internal)
          when "consume"
            Fenris::Base.consume(client, arg, name)
          when "exec"
            client.quiet = true
            Fenris::Base.exec(client, *args)
          else
            puts command.inspect
            puts help
        end
        exit
      end
    rescue SystemExit
    rescue RestClient::Conflict
      puts "Duplicate"
    rescue RestClient::Unauthorized
      puts "Unauthorized"
    rescue RestClient::ResourceNotFound
      puts "Resource Not Found"
      exit
    end
  end
end
