require 'sparkle_formation'
require 'sfn'
require 'sfn-serverspec/validator'

module Sfn
  class Command
    # Validate command
    class Serverspec < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      def execute!
        name_required!
        stack_name = name_args.last
        root_stack = stack(stack_name)

        print_only_original = config[:print_only]
        config[:print_only] = true
        load_template_file
        config[:print_only] = print_only_original
        api_action!(api_stack: root_stack) do
          ui.info "Serverspec validating stack #{ui.color(root_stack.name, :bold)} with template #{config[:file].sub(Dir.pwd, '').sub(%r{^/}, '')}:" # rubocop:disable LineLength
        end
      end
    end
  end
end
