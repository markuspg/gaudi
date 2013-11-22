module Gaudi
  module CompilationUnit
    #This is the default directory layout:
    # src/platform
    #         |-name/     - sources and local headers
    #             |-inc/  - public headers
    #             |-test/ - unit tests
    #
    #Code can be split in several source directories and by default we will look for the files in
    #source_directory/platform/name and source_directory/platform/name for every source_directory
    module StandardPaths
      def determine_directories name,source_directories,platform
        paths=source_directories.map{|source_dir| Rake::FileList["#{source_dir}/{#{platform},common}/#{name}"].existing}.inject(&:+)
        raise GaudiError,"Cannot find source directories for '#{name}' in #{paths.join(',')}" if paths.empty?
        return paths
      end
      def determine_sources component_directories
        Rake::FileList[*component_directories.pathmap("%p/**/*{#{src},#{asm}}")].exclude(*determine_test_directories(component_directories).pathmap('%p/*'))
      end
      def determine_headers component_directories
        Rake::FileList[*component_directories.pathmap("%p/**/*#{hdr}")].exclude(*determine_test_directories(component_directories).pathmap('%p/*'))
      end
      def determine_test_directories component_directories
        Rake::FileList[*component_directories.pathmap('%p/test')].existing
      end
      def determine_interface_paths component_directories
        Rake::FileList[*component_directories.pathmap("%p/inc")].existing
      end
    end
    #Conventions, naming and helpers for C projects
    module C
      include StandardPaths
      def src 
        '.c' 
      end
      def hdr 
        '.h' 
      end
      def asm
        '.asm' 
      end
    end
    #Conventions, naming and helpers for C++ projects
    module CPP
      include StandardPaths
      def src 
        '.cpp' 
      end
      def hdr 
        '.h' 
      end
      def asm 
        '.asm' 
      end
    end
  end

  #A Gaudi::Component is a logical grouping of a set of source and header files that maps to a directory structure.
  #
  #Given a base directory where sources reside, the name of Component is used to map to one or more Component source directories.
  #
  #By convention we define an inc/ directory where "public" headers reside. These headers form the interface of the Component
  #and the directory is exposed by Gaudi for use in include statements.
  class Component
    attr_reader :identifier,:platform,:configuration,:name,:directories
    def initialize name,comp_unit,system_config,platform
      extend comp_unit
      @directories = determine_directories(name,system_config.source_directories,platform)
      config_files = Rake::FileList[*directories.pathmap('%p/build.cfg')]
      @configuration = Configuration::BuildConfiguration.load(config_files)
      @system_config=system_config
      @platform=platform
      @name=@identifier=configuration.prefix
    end
    def sources
      determine_sources(directories)
    end
    #All headers
    def headers
      determine_headers(directories)
    end
    #The headers the component exposes
    def interface
      Rake::FileList[*include_paths.pathmap('%p/**/*#{HDR}')]
    end
    #The include paths for this Component
    def include_paths
      determine_interface_paths(directories)
    end
    #All files
    def all
      sources+headers
    end
    def dependencies
      configuration.dependencies.map{|dep| Component.new(dep,@system_config,platform)}
    end
  end
  #A Gaudi::Program is a collection of components linked together with the main() code
  #and built for a specific platform.
  class Program<Component
    def initialize config_file,deployment_name,system_config,platform
      @configuration=Configuration::BuildConfiguration.load([config_file])
      super(@configuration.prefix,system_config,platform)
      @deployment=deployment_name
    end
  end
  #A Deployment is a collection of Programs compiled for multiple platforms
  #
  #It maps to a directory structure of 
  # deployment
  #    |name
  #       |platform1
  #       |platform2
  #            |program1.cfg
  #            |program2.cfg
  class Deployment
    attr_reader :name
    def initialize name,system_config
      @name=name
      @directories=determine_directories(name,system_config.source_directories)
    end
    def platforms
      Rake::FileList[*@directories.pathmap("%p/*")].existing.pathmap('%n')
    end
    #A Program instance for every program configuration on the given platform
    def programs system_config,platform
      Rake::FileList[*@directories.pathmap("%p/#{platform}/*.cfg")].existing.map{|cfg| Program.new(cfg,name,system_config,platform)}
    end
    def to_s
      name
    end
  end
end