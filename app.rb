#coding: utf-8

require 'rubygems'
require 'Twitter'
require 'sinatra'
require 'sinatra/config_file'
require "open-uri"
require "FileUtils"

config_file 'config/app.yml'

client = nil

before do
  client = client || Twitter::REST::Client.new do |c|
    c.consumer_key = settings.twitter["auth"]["api-key"]
    c.consumer_secret = settings.twitter["auth"]["api-secret"]
    c.access_token = settings.twitter["auth"]["acess_token"]
    c.access_token_secret = settings.twitter["auth"]["acess_token_secret"]
  end
end

get "/" do
  data = client.favorites(settings.twitter["user"]["screen-name"])
  @html = ""
  data.each do |entity|
    @html += "<img src='#{entity.media[0].media_url}'/><br>" if entity.media[0]
  end

  erb :index
end

get '/api/get_tweet.json' do
  limit  = [ (params[:count] || 30).to_i, 150 ].min
  page   = (params[:page] || 1).to_i
  offset = (page - 1) * limit
  max_page  = (150 / limit).ceil
  next_page = max_page > page ? page + 1 : nil
  
  datas = client.favorites(settings.twitter["user"]["screen-name"])
  
  content_type :json
  {:datas => datas, :next => next_page}.to_json
end

get "/images" do
  count = get_count(params)
  max_id = get_max_id(params)
  result = get_favorited_images(client, count, max_id)
  
  urls = []
  result[:data].each do |e|
    e.media.each do |m|
      urls << "#{m.media_url}:large" if m
    end
  end
  
  content_type :json
  json = nil
  if result[:max_id]
    json = {:urls => urls, :max_id => result[:max_id]}.to_json
  else
    json = {:urls => urls}.to_json
  end
  
  json
end

get "/download" do
  count = get_count(params)
  max_id = get_max_id(params)
  result = get_favorited_images(client, count, max_id)
  root_dir = File.join(__FILE__, settings["download_dir"])
  
  result[:data].each do |e|
    e
    FileUtils.mkdir_p(dirName) unless FileTest.exist?(dirName)
  end
  
  
end

helpers do
  def get_favorited_images(client, count, max_id)
    result = []
    while result.size < count
      data = nil
      begin
        if !max_id
          data = client.favorites(settings.twitter["user"]["screen-name"], {count: count})
        else
          data = client.favorites(settings.twitter["user"]["screen-name"], {count: count, max_id: max_id})
        end
        p data
      rescue Twitter::Error::TooManyRequests => e
        p e.backtrace
      end
      
      break if !data || data.empty?
      
      data.each do |entity|
        result << entity if entity.media[0]
      end
      
      max_id = data[data.size-1].id - 1
    end
    return {data: result, max_id: max_id}
  end
  
  def get_count(params)
    [[(params[:count] || 20), 100].min, 1].max
  end
  
  def get_max_id(params)
    (params[:max_id] ? params[:max_id].to_i : nil)
  end
end



