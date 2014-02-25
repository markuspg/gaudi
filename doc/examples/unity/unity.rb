require 'gaudi'

module Gaudi::Configuration::SystemModules
  #System configuration parameters for the Unity 
  #unit testing framework
  module UnityConfiguration
    def self.list_keys
      []
    end

    def self.path_keys
      ['unity_test_generator']
    end
    #Point this to the Ruby script Unity uses to create test runners
    # unity_test_generator=path/to/unity/auto/generate_test_runner.rb
    def unity_test_generator
      return required_path(@config['unity_test_generator'])
    end
  end
end

module UnityOperations
  #Creates a file task that creates the test sunner for the given component
  def test_runner_task component,system_config
    src= test_runner(component,system_config)
    file src => commandfile_task(src,component,system_config) do |t|
      sources=component.test_files.select{|f| is_source?(f)}
      raise GaudiError,"No test sources for #{component.name}" if sources.empty?
      cmdline="ruby #{system_config.unity_test_generator} #{sources} #{t.name}" 
      mkdir_p(File.dirname(t.name),:verbose=>false)
      cmd=Patir::ShellCommand.new(:cmd=>cmdline)
      cmd.run
      if !cmd.success?
        puts [cmd,cmd.output,cmd.error].join("\n")
        raise GaudiError,"Creating test runner for #{name} failed"
      end
    end
  end
  #
  def test_runner component,system_config
    if component.test_directories.empty?
      raise GaudiError, "There are no tests for #{component.name}"
    else
      File.join(component.test_directories[0],"#{component.name}Runner.c")
    end
  end
end
#Most awesome way to bend the base class to our whim
class UnityTest < DelegateClass(Component)
  attr_reader :directories,:dependencies,:name
  def initialize component,system_config
    super(component)
    @directories=__getobj__.directories+__getobj__.test_directories
    @dependencies= [Component.new('Unity',system_config,platform)]
    @name="#{__getobj__.name}Test"
    @system_config=system_config
  end
  def sources
    __getobj__.sources+__getobj__.test_files.select{|src| is_source?(src)}
  end
  def headers
    __getobj__.headers+__getobj__.test_files.select{|src| is_header?(src)}
  end
  #External (additional) libraries the Program depends on.
  def external_libraries
    @system_config.external_libraries(platform)
  end
  #List of resources to copy with the program artifacts
  def resources
    @system_config.resources(platform)
  end
end