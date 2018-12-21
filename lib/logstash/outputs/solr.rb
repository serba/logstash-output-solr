# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"

require 'securerandom'
require "stud/buffer"
require 'rsolr'
require 'zk'
require 'rsolr/cloud'

# An Solr output that send data to Apache Solr.
class LogStash::Outputs::Solr < LogStash::Outputs::Base
  config_name "solr"

  include Stud::Buffer

  # The Solr server url (for example http://localhost:8983/solr/collection1).
  config :url, :validate => :string, :default => nil

  # The ZooKeeper connection string that SolrCloud refers to (for example localhost:2181/solr).
  config :zk_host, :validate => :string, :default => nil
  # The SolrCloud collection name.
  config :collection, :validate => :string, :default => 'collection1'

  # A field name with the name of collection to send document to
  config :collection_field, :validate => :string, :default => nil

  # Commit every batch?
  config :commit, :validate => :boolean, :default => false

  # A field name of unique key in the Solr schema.xml (default id)
  config :unique_key_field, :validate => :string, :default => 'id'
  
  # A field name of event timestamp in the Solr schema.xml (default event_timestamp).
  config :timestamp_field, :validate => :string, :default => 'timestamp_tdt'

  # Solr commitWithin parameter
  config :commitWithin, :validate => :number, :default => 10000

  # The batch size used in update.
  config :flush_size, :validate => :number, :default => 100

  # The batch size used in update.
  config :idle_flush_time, :validate => :number, :default => 10

  MODE_STANDALONE = 'Standalone'
  MODE_SOLRCLOUD = 'SolrCloud'

  public
  def register
    @mode = nil
    if ! @url.nil? then
      @mode = MODE_STANDALONE
    elsif ! @zk_host.nil?
      @mode = MODE_SOLRCLOUD
    end

    @solr = nil
    @zk = nil

    if @mode == MODE_STANDALONE then
      @solr = RSolr.connect :url => @url
    elsif @mode == MODE_SOLRCLOUD then
      @zk = ZK.new(@zk_host)
      cloud_connection = RSolr::Cloud::Connection.new(@zk)
      @solr = RSolr::Client.new(cloud_connection, read_timeout: 60, open_timeout: 60)
    end

    buffer_initialize(
      :max_items => @flush_size,
      :max_interval => @idle_flush_time,
      :logger => @logger
    )
  end # def register

  public
  def receive(event)
    buffer_receive(event)
  end # def event

  public
  def flush(events, close=false)
    documents_per_col = {}

    events.each do |event|
      document = event.to_hash()

      unless document.has_key?(@unique_key) then
        document.merge!({@unique_key => SecureRandom.uuid})
      end
      
      unless document.has_key?(@timestamp_field) then
        document.merge!({@timestamp_field => document['@timestamp']})
      end
      
      @logger.info 'Record: %s' % document.inspect

      if !@collection_field and document.has_key?(@collection_field) then
        collection = document[@collection_field]
      else
        collection = @collection
      end
      
      documents = documents_per_col.fetch(collection, [])
      documents.push(document)
      documents_per_col[collection] = documents
    end

    params = {}
    if @commit
      params[:commit] = true
    end  
    params[:commitWithin] = @commitWithin
    
    hash.each do |collection, documents|
      if @mode == MODE_STANDALONE then
        @solr.add documents, :params => params
        @logger.info 'Added %d document(s) to Solr' % documents.count
      elsif @mode == MODE_SOLRCLOUD then
        @solr.add documents, collection: @collection, :params => params
        @logger.info 'Added %d document(s) to "%s" collection' % documents.count, collection
      end
    end

    rescue Exception => e
      @logger.warn("An error occurred while indexing", :exception => e.inspect)
  end # def flush

  public
  def close
    unless @zk.nil? then
      @zk.close
    end
  end # def close

end # class LogStash::Outputs::Solr
