# SparkleFormation ServerSpec Callback

sfn-serverspec is a [callback](http://www.sparkleformation.io/docs/sfn/callbacks.html) for [sfn](https://github.com/sparkleformation/sfn) which executes [Serverspec](http://serverspec.org) assertions against stack compute resources after successful stack creation.

## Usage

### Enable

Callbacks are configured via the `.sfn` configuration file. First, the callback must be enabled:

```ruby
Configuration.new do
  callbacks do
    require ['sfn-serverspec']
    default ['serverspec_validator']
  end
end
```

### Configure

Some configuration of callback behavior is available via the `.sfn` file:

```ruby
Configuration.new do
  sfn_serverspec do
    global_spec_patterns [File.join(Dir.pwd, 'spec/base/*_spec.rb')]
    ssh_proxy_command 'ssh ec2-user@server.example.com nc %h %p'
    ssh_user 'ubuntu'
  end
end
```

All of the following settings are optional:

* `global_spec_patterns` - Array of strings specifying file paths for specs, defaults to `[]`
* `ssh_proxy_command` - String passed as the [proxy command for remote SSH connection](http://continuousimprovement.me/code/2014/12/03/serverspec-behind-jump-server.html) to the target compute resource, defaults to `nil`
* `ssh_user` - Username for remote SSH connection, defaults to `ec2-user`
* `ssh_port` - Port for remote SSH connection, defaults to `22`
* `ssh_key_paths` - Array of strings describing paths to one or more ssh private keys, defaults to `[]`
* `ssh_key_passphrase` - String used as passphrase for any encrypted ssh private keys defined in `ssh_key_paths`, defaults to `nil`

Additional configuration may be provided in a SparkleFormation template at the resource level:

```ruby
resources(:my_cool_app_asg) do
  type 'AWS::AutoScaling::AutoScalingGroup'
  properties do
    # ...
  end
  serverspec do
    spec_patterns [File.join(Dir.pwd, '../spec/my_cool_app/*_spec.rb')]
  end
end
```

For each resource with a `serverspec` block defined, the resource-level value of `spec_patterns` is combined with the value of `global_spec_patterns` from the .sfn config file to yield a list of specs which will be executed against a given resource.

The following configuration options specified at the resource level will override the same options specified in the .sfn config file:

* `ssh_user`
* `ssh_port`
* `ssh_proxy_command`
* `ssh_key_paths`
* `ssh_key_passphrase`

### On-demand validation

Provided that you are using Bundler, this callback also adds a `serverspec` command to sfn, enabling on-demand validation of a running stack. You'll want to add sfn-serverspec to your Gemfile thusly:

```ruby
group :sfn do
  gem 'sfn'
  gem 'sfn-serverspec'
end
```

Note that placing sfn and its friends in the `:sfn` group ensures that they'll be automatically `require`-d by sfn at run time.

The `serverspec` command requires both a stack name and a template to use as the source of Serverspec configuration. The template may be provided via command line flag or interactive file path prompt:

```
$ bundle exec sfn serverspec example-stack -f sparkleformation/example.rb
[Sfn]: Callback template serverspec_validator: starting
[Sfn]: Callback template serverspec_validator: complete
[Sfn]: Serverspec validating stack example-stack with template sparkleformation/example.rb:
[Sfn]: Callback after_serverspec serverspec_validator: starting
[Sfn]: Serverspec validating i-55836892 (10.101.100.15)

base
Port "22"
should be listening

hello world
displays a custom message on the index page
Port "80"
should be listening

Finished in 2.92 seconds (files took 10.49 seconds to load)
3 examples, 0 failures

[Sfn]: Serverspec validating i-52836895 (10.101.100.19)

Port "22"
should be listening

hello world
displays a custom message on the index page
Port "80"
should be listening

Finished in 0.35415 seconds (files took 13.41 seconds to load)
3 examples, 0 failures

[Sfn]: Callback after_serverspec serverspec_validator: complete
```

## Caveats

Providing `serverspec` configuration on compute resources works in a manner similar to sfn's built-in Stack Policy callback. Specifically, the `serverspec` key and its contents are removed from the template during compile, cached by the callback and executed after completion of stack creation.

As of this writing, the callback only processes Serverspec configuration on `AWS::AutoScaling::AutoScalingGroup` and `AWS::EC2::Instance` resources.

Non-compute resources with `serverspec` configuration will not be processed by this callback, and will probably yield a validation error when trying to validate or create a stack from the template.

## Info

* Repository: [https://github.com/sparkleformation/sfn-serverspec](https://github.com/sparkleformation/sfn-serverspec)
* IRC: Freenode @ #sparkleformation
