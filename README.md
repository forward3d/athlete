# Athlete

Athlete is a Capistrano-like deployment tool for deploying Docker
containers into [Marathon](https://mesosphere.github.io/marathon/).

Warning: Athlete is at best a beta. It may not understand all Marathon responses, it
lacks some features, and it doesn't do some basic error checking. Use at your own risk. 
Pull requests welcomed. YMMV.

## Why Athlete exists

If you're a Ruby developer, Capistrano makes things so fantastically easy that you miss it when
you start to package apps as Docker containers.

Athlete was written to become, internally, a simple Capistrano-like tool that allows developers
to quickly and easily deploy to our Marathon cluster.

## Features

- Simple DSL for defining Docker builds and deployments
- Detects deployment failures
- Simple (~750 LoC)
- Allows Marathon properties to be set outside deployments or forced

## Installation

Add these lines to your application's Gemfile, in the `:development` group:

    group :development do
      ... some other gems ...
      gem 'athlete'
    end

And then execute:

    bundle install --binstubs

Athlete isn't required at runtime.

## Usage

Athlete performs two actions: building, and deploying.

An Athlete build runs `docker build`, tags the image appropriately
(including the registry name if you're using a private registry),
and the pushes it to the registry. This push step can be skipped.

An Athlete deploy uses Marathon's REST API to deploy one of the Docker
containers built in the build step or any arbitrary Docker container - 
you are not limited to only deploying containers you built.

### Command line usage

(You may want to read the configuration section first, since you
need a configuration before you can do anything.)

To get help with the CLI:

    bin/athlete help

To build all builds in the configuration file:

    bin/athlete build

To build all builds put not push them:

    bin/athlete build --no-push

To deploy all deployments in the configuration file:

    bin/athlete deploy

### Configuration

Athlete is configured using a simple DSL.

By default, it expects the configuration file to be called `athlete.rb` and
to be placed in the `config` directory relative to the base of your app.

__Todo: write a command to produce a template athlete.rb file__

A build takes some information about the name you want to give your 
container, how it should be versioned, and what registry it should be pushed to. 

A deployment takes some information about where to deploy to, how many
instances to run, how much CPU and memory resource to allocate, and so on.

Here's an example of a simple image build and deploy:

```ruby
Athlete::Build.define('my-image') do
  registry 'my-registry:5000'
  version '1'
end

Athlete::Deployment.define('my-app') do
  marathon_url 'http://marathon:8080'
  # image_name 'ubuntu:12.04'
  # command ['/bin/sleep', '600']
  # arguments ['something']
  # environment_variables {'RACK_ENV' => 'production'}
  build_name 'my-image'
  cpus 1, :override
  memory 128, :inherit
  instances 1, :override
  minimum_health_capacity 0.5, :inherit
end
```

This will build an image tagged `my-registry:5000/my-image:1`, remembering
that the Docker image conventions are: `registry_url:registry_port/image_name:image_version`.

Once built, it will deploy a container based on that image to the Marathon host
at `http://marathon:8080`. It will request 1 CPU and 128MB of RAM from Marathon,
and run one instance of the container. See below for details of what the property
`minimum_health_capacity` does.

#### Build DSL reference

| Property | Required | Description |
| -------- | -------- | ----------- |
| registry | no       | The Docker registry to push to - if unspecified, we use the Docker Hub. |
| version  | yes      | How to version the image; this can be any stringifiable object, or the symbol `:git`, which will version using the output of `git rev-parse HEAD` |

#### Deployment DSL reference

Some properties are defined with an extra parameter which is either
`:override` or `:inherit` - in the above example, `instances 1, :override`
is specified with `:override`, and `memory 128, :inherit` is specified with
`:inherit`.

These properties are ones that can be varied in Marathon through other means.
For example, you may have a separate 'scaling' system that changes the number
of instances of a container in response to some parameter. Let's say that it
has acted to increase the number of instances to 5, and our `athlete.rb` has
this line in the deployment section:

    instances 1, :override

When you deploy, Athlete will see that Marathon's currently running value for
instances of the app is 5, and that you set it to 1 in your deployment configuration
with :override, and it will _force_ there to be only 1 instance after the deployment.

This would be non-ideal, since your scaling system is 'authoritative' for this 
property - it decides how many instances should run. Resetting it when you deploy
could break production!

If you had set the instances property to be `:inherit`, like so:

    instances 1, :inherit

Then when you run a deploy, Athlete will completely ignore the instance value set in
the configuration file, and just trust whatever is currently set in Marathon.

The only time _all parameters_ will be sent to Marathon is when an app
does not already exist. In that case, we have to supply some initial values to get the app going.

##### `marathon_url`

__required___: yes
__override/inherit__: no

The URL to the Marathon REST API endpoint you're using.

##### `build_name` 

__required___: yes (if not supplying `image_name`)
__override/inherit__: no

The build name to get Docker image information from. You must
reference a build defined earlier in the `athlete.rb` file. The name of a build
is the string supplied to the `define` call. E.g.

    Athlete::Build.define('my-image') do
      registry 'my-registry:5000'
      version '1'
    end

You would reference this by setting:

    build_name 'my-image'

in your deployment definition.

It is required if you are not specifying `image_name`.

##### `image_name`

__required___: yes (if not supplying `build_name`)
__override/inherit__: no

The Docker image name to deploy. You must specify the entire image name,
including whatever tagged version you want. E.g. `ubuntu:12.04`.

It is required if you are not specifying `build_name`.

##### `command`

__required___: no
__override/inherit__: no

The command to run inside the Docker container. This will override
the `CMD` section of the Dockerfile. This should be specified in
an array form, as discussed [here](https://docs.docker.com/reference/builder/#cmd).

##### `arguments`

__required___: no
__override/inherit__: no

Arguments to supply to the container's ENTRYPOINT.

##### `cpus`

__required___: yes (on a cold deploy)
__override/inherit__: yes

CPU resource to request for this app. This can be a fractional value (e.g. 0.1).

##### `memory`

__required___: yes (on a cold deploy)
__override/inherit__: yes

Memory to request for this app in MB.

##### `environment_variables`

__required___: no
__override/inherit__: no

Environment variables to pass into the container at startup - must be specified
as a hash of `ENV_VAR_NAME => ENV_VAR_VALUE`.

##### `instances`

__required___: no
__override/inherit__: yes

Number of instances of the container to run.

##### `minimum_health_capacity`

__required___: no
__override/inherit__: yes

This description is taken from the 
[Marathon documentation](https://mesosphere.github.io/marathon/docs/rest-api.html#post-/v2/apps).

> During an upgrade all instances of an application get replaced by a new version. 
> The minimumHealthCapacity defines the minimum number of healthy nodes, that do not sacrifice 
> overall application purpose. It is a number between 0 and 1 which is multiplied with the 
> instance count. The default minimumHealthCapacity is 1, which means no old instance can be stopped, 
> before all new instances are deployed. A value of 0.5 means that an upgrade can be deployed side by side, 
> by taking half of the instances down in the first step, deploy half of the new version and 
> then take the other half down and deploy the rest. A value of 0 means take all instances down 
> immediately and replace with the new application.

## Contributing

1. Fork it ( https://github.com/forward3d/athlete/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request
