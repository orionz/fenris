require 'optparse'
require 'socket'
require 'ostruct'
require 'uri'

module Fenris
  class Command
    def self.run(args)
      begin
        run_command(args)
      rescue RestClient::Conflict
        puts "Duplicate"
      rescue RestClient::Unauthorized
        puts "Unauthorized"
      rescue RestClient::ResourceNotFound
        puts "Resource Not Found"
      rescue Fenris::NoSuchProvider => e
        puts "No such provider '#{e.message}'"
        exit
      end
    end

    def self.run_command(args)
      url = URI.parse(ENV['FENRIS_URL'] || 'https://broker.fenris.cc/')
      args, options, help = parse(args)
      fenris = Fenris::Client.new url, options
      command = args.shift
      arg = args.first

      case [ command, args.length ]
      when [ "info", 0 ]
        fenris.update_user_config
        printf "INFO:\n"
        printf "  %s\n", fenris.user_name
        unless fenris.users.empty?
          puts "SUBACCOUNTS:"
          fenris.users.each { |c| printf "  %-20s\n", c["name"] }
        end
        unless fenris.consumers.empty?
          puts "CLIENTS:"
          fenris.consumers.each { |c| printf "  %-20s\n", c["name"] }
        end
        unless fenris.providers.empty?
          puts "SERVICES:"
          fenris.providers.each { |c| printf "  %-20s  [%s] %s\n", c["name"], c["binding"], c["location"] }
        end
      when [ "useradd", 1 ]
        fenris.useradd(arg)
        puts "user added"
      when [ "userdel", 1 ]
        fenris.userdel(arg)
        puts "ok"
      when [ "bind", 2 ]
        fenris.bind(args[0], args[1])
      when [ "sync", 0 ]
        fenris.update_config
      when [ "rekey", 0 ]
        fenris.rekey
        puts "rekey complete"
      when [ "add", 1 ]
        fenris.add(arg)
        puts "ok"
      when [ "remove", 1 ]
        fenris.remove(arg)
        puts "ok"
      when [ "provide", 1 ]
        fenris.provide(arg)
      when [ "consume", 0 ]
        fenris.consume
      when [ "consume", 1 ]
        fenris.consume(arg)
      when [ "consume", 2 ]
        fenris.consume(args[0] => args[1])
      else
        case command
        when "exec"
          options.quiet = true
          Fenris::Client.new(url, options).exec(*args)
        else
          puts help
          exit
        end
      end
    end

    def self.parse(args)
      extra = []
      options = OpenStruct.new
      options.port     = 10001
      options.host     = Socket.gethostname
      options.user     = ENV['FENRIS_USER']
      options.password = ENV['FENRIS_AUTHKEY']
      options.config   = ENV['FENRIS_CONFIG'] || "#{ENV["HOME"]}/.fenris"
      options.debug    = !! ENV['FENRIS_DEBUG']
      options.autosync = true

      if i = args.index("exec")
        extra = args[i..(args.length)]
        if i > 0
          args  = args[0..(i-1)]
        else
          args  = []
        end
      end

      opts = OptionParser.new do |opts|
        opts.banner    = "Usage: fenris [options] COMMAND"
        opts.separator ""
        opts.separator "Commands:"
        opts.separator ""
        opts.separator "  fenris info                          # info about current user and connections"
        opts.separator "  fenris useradd NAME                  # create a new subaccount"
        opts.separator "  fenris userdel NAME                  # delete a subaccount"
        opts.separator "  fenris add USER                      # allow USER to consume service"
        opts.separator "  fenris remove USER                   # disallow USER to consume service"
        opts.separator "  fenris provide BINDING               # provide a local service"
        opts.separator "  fenris consume [ USER [ BINDING ] ]  # consume one (or all) remote services"
        opts.separator "  fenris exec COMMAND                  # consume services and run COMMAND.  Terminates when command exits."
        opts.separator "  fenris sync                          # sync config with broker"
        opts.separator "  fenris rekey                         # generate a new authkey for the user"
        opts.separator "  fenris bind USER BINDING             # bind a remote service to a local binding"
        opts.separator ""
        opts.separator "Bindings can take the form of:"
        opts.separator ""
        opts.separator "  PORT, :PORT, HOST:PORT, /PATH/TO/UNIX_SOCKET, or -- for STDIN"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-u", "--user USER", "Connect as USER.  Default is $FENRIS_USER.") do |user|
          options.user = user
        end

        opts.on("-c", "--config DIR", "Store config information in DIR.  Default is $HOME/.fenris or $FENRIS_CONFIG.") do |dir|
          options.config = dir
        end

        opts.on("-h", "--hostname HOST", "Hostname given to consumers on 'provide'. Default is `hostname`.") do |host|
          options.host = host
        end

        opts.on("-p", "--port PORT", "") do |port|
          options.port = port
        end

        opts.on("-q", "--quiet", "Do not print log messages.") do
          options.quiet = true
        end

        opts.on("-d", "--debug", "Print debugging messages.  Default is $FENRIS_DEBUG.") do
          options.debug = true
        end

        opts.on("-a", "--[no-]autosync", "Automatically sync updates from the broker. Default is true.") do |auto|
          options.autosync = auto
        end

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on("--version", "Show version") do
          puts Fenris::VERSION
          exit
        end
        opts.separator ""
      end

      begin
        commands = opts.parse!(args)
      rescue OptionParser::InvalidOption
        puts opts
        exit
      end
      [ commands + extra, options, opts.to_s ]
    end
  end
end
