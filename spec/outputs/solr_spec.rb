# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/solr"
require "logstash/codecs/plain"
require "logstash/event"

require 'zk-server'
require 'zk'

describe LogStash::Outputs::Solr do

  before do
    @zk_server = nil
  end

  describe 'configuration' do
    let(:config) {
      {
        'url' => 'http://localhost:8983/solr/collection1',
        'zk_host' => 'localhost:2181/solr',
        'collection' => 'collection1',
        'flush_size' => 100,
        'commit' => false,
        'commitWithin' => 10000
      }
    }

    it 'url' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['url']).to eq('http://localhost:8983/solr/collection1')
    end

    it 'zk_host' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['zk_host']).to eq('localhost:2181/solr')
    end

    it 'collection' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['collection']).to eq('collection1')
    end

    it 'flush_size' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['flush_size']).to eq(100)
    end

    it 'commit' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['commit']).to eq(false)
    end

    it 'commitWithin' do
      output = LogStash::Outputs::Solr.new(config)
      expect(output.config['commitWithin']).to eq(10000)
    end
  end

  describe 'register_standalone' do
    let(:config) {
      {
        'url' => 'http://localhost:8983/solr/collection1',
        'flush_size' => 100
      }
    }

    it 'mode' do
      output = LogStash::Outputs::Solr.new(config)
      output.register

      mode = output.instance_variable_get('@mode')
      expect(mode).to eq('Standalone')
    end
  end

  describe 'register_solrcloud' do
    before do
      start_zookeeper
    end

    after do
      stop_zookeeper
    end

    let(:config) {
      {
        'zk_host' => 'localhost:3292/solr',
        'collection' => 'collection1',
        'flush_size' => 100
      }
    }

    it 'mode' do
      output = LogStash::Outputs::Solr.new(config)
      output.register

      mode = output.instance_variable_get('@mode')
      expect(mode).to eq('SolrCloud')
    end
  end

  describe 'receive_standalone' do
    let(:config) {
      {
        'url' => 'http://localhost:8983/solr/collection1',
        'flush_size' => 100
      }
    }

    let(:sample_record) {
      {
        'id' => 'change.me',
        'title' => 'change.me'
      }
    }

    it 'receive' do
      output = LogStash::Outputs::Solr.new(config)
      output.register

      output.receive(sample_record)
    end
  end

  describe 'receive_solrcloud' do
    before do
      start_zookeeper
    end

    after do
      stop_zookeeper
    end

    let(:config) {
      {
        'zk_host' => 'localhost:3292/solr',
        'collection' => 'collection1',
        'flush_size' => 100
      }
    }

    let(:sample_record) {
      {
        'id' => 'change.me',
        'title' => 'change.me'
      }
    }

    it 'receive' do
      output = LogStash::Outputs::Solr.new(config)
      output.register

      output.receive(sample_record)
    end
  end

  describe 'multiple_collections' do
    before do
      start_zookeeper
    end

    after do
      stop_zookeeper
    end

    let(:config) {
      {
        'zk_host' => 'localhost:3292/solr',
        'collection_field' => 'collection',
        'flush_size' => 100
      }
    }

    let(:sample_record1) {
      {
        'id' => 'test1',
        'collection' => 'col1'
      }
    }
    let(:sample_record2) {
      {
        'id' => 'test2',
        'collection' => 'col2'
      }
    }
    let(:sample_record3) {
      {
        'id' => 'test3'
      }
    }

    it 'receive' do
      output = LogStash::Outputs::Solr.new(config)
      output.register

      output.receive(sample_record1)
      output.receive(sample_record2)
      output.receive(sample_record3)
    end
  end

  def start_zookeeper
    @zk_server = ZK::Server.new do |config|
      config.client_port = 3292
      config.enable_jmx = true
      config.force_sync = false
    end

    @zk_server.run

    zk = ZK.new('localhost:3292')
    delete_nodes(zk, '/solr')
    create_nodes(zk, '/solr/live_nodes')
    ['localhost:8983_solr'].each do |node|
      zk.create("/solr/live_nodes/#{node}", '', mode: :ephemeral)
    end
  end

  def stop_zookeeper
    @zk_server.shutdown
  end

  def delete_nodes(zk, path)
    zk.children(path).each do |node|
      delete_nodes(zk, File.join(path, node))
    end
    zk.delete(path)
  rescue ZK::Exceptions::NoNode
  end

  def create_nodes(zk, path)
    parent_path = File.dirname(path)
    unless zk.exists?(parent_path, :watch => true) then
      create_nodes(zk, parent_path)
    end
    zk.create(path)
  end
end


