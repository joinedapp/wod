require 'wod/helpers'
require 'wod/commands/base'

Dir["#{File.dirname(__FILE__)}/commands/*.rb"].each { |c| require c }

module Wod
  module Command
    class InvalidCommand < RuntimeError; end
    class CommandFailed  < RuntimeError; end
    
    extend Wod::Helpers
    
    def self.run(command, args, retries=0)
      begin
        run_internal 'auth:reauthorize', args.dup if retries > 0
        run_internal command, args.dup
      rescue InvalidCommand
        error "Unknown command. Run 'wod help' for usage information."
      rescue Wod::InvalidCredentials
        if retries < 3
          STDERR.puts "Authentication failure"
          run command, args, retries + 1
        else
          error "Authentication failure"
        end
      rescue Wod::NoTeamSelected
        STDERR.puts "No team selected"
        run command, args, retries + 1
      end
    end
    
    def self.run_internal(command, args, wod=nil)
      klass, method = parse command
      runner = klass.new args, wod
      raise InvalidCommand unless runner.respond_to?(method)
      runner.send method
    end
    
    def self.parse(command)
      parts = command.split(':')
      case parts.size
        when 1
          begin
            return eval("Wod::Command::#{command.capitalize}"), :index
          rescue NameError, NoMethodError
            return Wod::Command::App, command.to_sym
          end
        else
          begin
            const = Wod::Command
            command = parts.pop
            parts.each { |part| const = const.const_get(part.capitalize) }
            return const, command.to_sym
          rescue NameError
            raise InvalidCommand
          end
      end
    end
    
  end
end