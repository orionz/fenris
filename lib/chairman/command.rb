module Chairman
  module Command
    def self.run(command, arg)
      help = "Usage: chairman serve PORT\n" +
             "       chairman connect [DIR]"
      case command
        when "serve"
          from = 10001
          to = arg.to_i
          Chairman::Base.serve(from,to) if arg.to_i > 0
        when "connect"
          dir = arg || Dir.pwd
          Chairman::Base.connect(dir)
      end
      puts help
      exit
    end
  end
end
