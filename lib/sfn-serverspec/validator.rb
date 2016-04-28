require 'json'
require 'net/ssh'
require 'net/ssh/proxy/command'
require 'rspec'
require 'rspec/core/formatters/documentation_formatter'
require 'bogo-config/configuration'
require 'serverspec'
require 'sfn'

module Sfn
  # This is an sfn callback
  class Callback
    # Validate stack resources against Serverspec assertions
    class ServerspecValidator < Callback # rubocop:disable ClassLength
      # @return [Smash] cached policies
      attr_reader :policies

      # Overload to init policy cache
      #
      # @return [self]
      def initialize(*args)
        super
        @policies = Smash.new
      end

      def after_create(*args)
        policies.each do |resource, r_config|
          resource_config = r_config.dump!.to_smash(:snake)

          ssh_proxy_command = resource_config.fetch(
            :ssh_proxy_command,
            config.fetch(:sfn_serverspec, :ssh_proxy_command, nil)
          )

          ssh_key_paths = [
            resource_config.fetch(
              :ssh_key_paths,
              config.fetch(:sfn_serverspec, :ssh_key_paths, nil)
            )
          ].flatten.compact

          ssh_key_passphrase = resource_config.fetch(
            :ssh_key_passphrase,
            config.fetch(:sfn_serverspec, :ssh_key_passphrase, nil)
          )

          instances = expand_compute_resource(args.first[:api_stack], resource)

          instances.each do |instance|
            target_host = case ssh_proxy_command.nil?
                          when true
                            instance.addresses_public.first.address
                          when false
                            instance.addresses_private.first.address
                          end

            begin
              rspec_config = RSpec.configuration
              rspec_config.reset
              rspec_config.reset_filters
              RSpec.world.reset

              rspec_formatter = RSpec::Core::Formatters::DocumentationFormatter.new(
                rspec_config.output_stream
              )

              rspec_reporter = RSpec::Core::Reporter.new(rspec_config)

              rspec_config.instance_variable_set(:@reporter, rspec_reporter)
              rspec_loader = rspec_config.send(:formatter_loader)
              rspec_notifications = rspec_loader.send(
                :notifications_for,
                RSpec::Core::Formatters::DocumentationFormatter
              )
              rspec_reporter.register_listener(
                rspec_formatter,
                *rspec_notifications
              )

              global_specs = [
                config.fetch(:sfn_serverspec, :global_spec_patterns, [])
              ].flatten.compact

              resource_specs = [
                resource_config.fetch(:spec_patterns, [])
              ].flatten.compact

              spec_patterns = global_specs + resource_specs

              ui.debug "spec loading patterns: #{spec_patterns.inspect}"
              ui.debug "using SSH proxy commmand #{ssh_proxy_command}" unless ssh_proxy_command.nil?
              ui.info "Serverspec validating #{instance.id} (#{target_host})"

              Specinfra.configuration.backend :ssh
              Specinfra.configuration.request_pty true
              Specinfra.configuration.host target_host

              connection_options = {
                user: resource_config.fetch(
                  :ssh_user,
                  config.fetch(:sfn_serverspec, :ssh_user, 'ec2-user')
                ),
                port: resource_config.fetch(
                  :ssh_port,
                  config.fetch(:sfn_serverspec, :ssh_port, 22)
                )
              }

              unless ssh_proxy_command.nil?
                connection_options[:proxy] = Net::SSH::Proxy::Command.new(ssh_proxy_command)
                ui.debug "using ssh proxy command: #{ssh_proxy_command}"
              end

              unless ssh_key_paths.empty?
                connection_options[:keys] = ssh_key_paths
                ui.debug "using ssh key paths #{connection_options[:keys]} exclusively"
              end

              unless ssh_key_passphrase.nil?
                connection_options[:passphrase] = ssh_key_passphrase
              end

              Specinfra.configuration.ssh_options connection_options

              RSpec::Core::Runner.run(spec_patterns.map { |p| Dir.glob(p) })

            rescue => e
              ui.error "Something unexpected happened when running rspec: #{e.inspect}"
            end
          end
        end
      end

      alias_method :after_serverspec, :after_create
      alias_method :after_update, :after_create

      COMPUTE_RESOURCE_TYPES = ['AWS::EC2::Instance', 'AWS::AutoScaling::AutoScalingGroup']

      # Generate policy for stack, collate policies in cache
      #
      # @return [nil]
      def template(info)
        compiled_stack = info[:sparkle_stack].compile

        compiled_stack.resources.keys!.each do |r|
          r_object = compiled_stack.resources[r]
          if COMPUTE_RESOURCE_TYPES.include?(r_object['Type']) && r_object['Serverspec']
            @policies.set(r, r_object.delete!('Serverspec'))
          end
        end
      end

      private

      # detect nested stacks, return array of expanded stacks
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @param name [String]
      # @return [Array<Miasma::Models::Compute::Server>]
      def expand_nested_stacks(stack)
        stack.resources.all.map do|r|
          r.expand if r.type == 'AWS::CloudFormation::Stack'
        end
      end

      # look up stack resource by name, return array of expanded compute instances
      #
      # @param stack [Miasma::Models::Orchestration::Stack]
      # @param name [String]
      # @return [Array<Miasma::Models::Compute::Server>]
      def expand_compute_resource(stack, name)
        compute_resource = stack.resources.all.detect do |resource|
          resource.logical_id == name
        end

        if compute_resource.nil?
          ui.info "No compute resources found in stack #{name}"
          return []
        end

        if compute_resource.within?(:compute, :servers)
          [compute_resource.expand]
        else
          compute_resource.expand.servers.map(&:expand)
        end
      end
    end
  end
end

# Override the `#set` method provided by Serverspec to ensure any
# `spec_helper.rb` files do not clobber our configuration setup

alias :serverspec_set :set # rubocop:disable Alias

def set(*args)
  serverspec_set(args.first)
end
