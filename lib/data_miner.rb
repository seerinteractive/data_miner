require 'active_support'
require 'active_record'
require 'blockenspiel'
require 'conversions'
require 'remote_table'
require 'errata'
require 'andand'
require 'log4r'

require 'data_miner/attribute'
require 'data_miner/configuration'
require 'data_miner/dictionary'
require 'data_miner/import'
require 'data_miner/process'
require 'data_miner/run'

# TODO: move to gem
require 'data_miner/william_james_cartesian_product'

module DataMiner
  class MissingHashColumn < RuntimeError; end
  
  include Log4r

  mattr_accessor :logger
  
  def self.start_logging
    if defined?(Rails)
      self.logger = Rails.logger
    else
      self.logger = Logger.new 'data_miner'
      logger.outputters = FileOutputter.new 'f1', :filename => 'data_miner.log'
    end
  end
  
  def self.run(options = {})
    DataMiner::Configuration.run options
  end
  
  def self.resource_names
    DataMiner::Configuration.resource_names
  end
  
  def self.create_tables
    DataMiner::Configuration.create_tables
  end
end

ActiveRecord::Base.class_eval do
  def self.data_miner(&block)
    unless table_exists?
      logger.error "[DataMiner gem] Database table `#{table_name}` doesn't exist. DataMiner probably won't work properly until you run a migration or otherwise fix the schema."
      return
    end
    
    DataMiner.resource_names.add self.name
    DataMiner.create_tables

    belongs_to :data_miner_last_run, :class_name => 'DataMiner::Run'
    
    # this is class_eval'ed here so that each ActiveRecord descendant has its own copy, or none at all
    class_eval { cattr_accessor :data_miner_config }
    self.data_miner_config = DataMiner::Configuration.new self

    Blockenspiel.invoke block, data_miner_config
    data_miner_config.after_invoke
  end
end

DataMiner.start_logging
