=begin

  Copyright (C) 2013 Keisuke Nishida

  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.

=end

module Fluent

class SplunkAPIOutput < BufferedOutput
  Plugin.register_output('splunkapi-ssln', self)

  config_param :protocol, :string, :default => 'rest'

  # for Splunk REST API
  config_param :server, :string, :default => 'localhost:8089'
  config_param :verify, :bool, :default => true
  config_param :auth, :string, :default => nil # TODO: required with rest

  # Event parameters
  config_param :check_index, :bool, :default => true
  config_param :index, :string, :default => 'index'

  # Retry parameters
  config_param :post_retry_max, :integer, :default => 5
  config_param :post_retry_interval, :integer, :default => 5

  def initialize
    super
    require 'net/http/persistent'
    require 'json'
    @idx_indexers = 0
    @indexers = []
  end

  def configure(conf)
    super

    if @server.match(/,/)
      @indexers = @server.split(',')
    else
      @indexers = [@server]
    end
  end

  def start
    super
    @http = Net::HTTP::Persistent.new 'fluentd-plugin-splunkapi'
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless @verify
    @http.headers['Content-Type'] = 'text/plain'
    log.info "initialized for splunkapi"
  end

  def shutdown
    # NOTE: call super before @http.shutdown because super may flush final output
    super

    @http.shutdown
    log.debug "shutdown from splunkapi"
  end

  def format(tag, time, record)
    event = "#{record.to_json}\n"
    [tag, event].to_msgpack
  end

  def chunk_to_buffers(chunk)
    buffers = {}
    chunk.msgpack_each do |tag, message|
      event = JSON.parse(message)
      uri = get_baseurl(tag, event)
      (buffers[uri] ||= []) << event['payload']
    end
    return buffers
  end

  def write(chunk)
    chunk_to_buffers(chunk).each do |url, messages|
      uri = URI url
      post = Net::HTTP::Post.new uri.request_uri
      post.basic_auth @username, @password
      post.body = messages.join('')
      log.debug "POST #{uri}"
      # retry up to :post_retry_max times
      1.upto(@post_retry_max) do |c|
        response = @http.request uri, post
        log.debug "=> #{response.code} (#{response.message})"
        if response.code == "200"
          # success
          break
        elsif response.code.match(/^40/)
          # user error
          log.error "#{uri}: #{response.code} (#{response.message})\n#{response.body}"
          break
        elsif c < @post_retry_max
          # retry
          sleep @post_retry_interval
          next
        else
          # other errors. fluentd will retry processing on exception
          # FIXME: this may duplicate logs when using multiple buffers
          raise "#{uri}: #{response.message}"
        end
      end
    end
  end

  def get_baseurl(key, event)
    base_url = ''
    @username, @password = @auth.split(':')
    server = @indexers[@idx_indexers];
    @idx_indexers = (@idx_indexers + 1) % @indexers.length
    base_url = "https://#{server}/services/receivers/simple?sourcetype=#{key}"
    base_url += "&host=#{event['host']}"
    base_url += "&index=#{@index}"
    base_url += "&source=#{event['source']}"
    base_url += "&check-index=false" unless @check_index
    base_url
  end
end

# Module close
end
