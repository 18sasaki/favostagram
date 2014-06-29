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
  erb :index
end

get "/images" do
  count = get_count(params)
  max_id = get_max_id(params)
  result = get_favorited_images(client, count, max_id)

  urls = []
  result[:data].each do |e|
    e.media.each do |m|
      urls << "#{m.media_url}" if m
    end
  end

  # urls = case count
  #        when 50
  #         p ">>>>>>>>>>>> 50!"
  #         [
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://ustat.pashaoku.jp/auction/547743/0/L_d542a520-7a94-4cc4-a5fc-483c25fbcb50',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg',
  #           'http://lohas.nicoseiga.jp/thumb/3141793i',
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://ustat.pashaoku.jp/auction/547743/0/L_d542a520-7a94-4cc4-a5fc-483c25fbcb50',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg',
  #           'http://lohas.nicoseiga.jp/thumb/3141793i',
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://ustat.pashaoku.jp/auction/547743/0/L_d542a520-7a94-4cc4-a5fc-483c25fbcb50',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg',
  #           'http://lohas.nicoseiga.jp/thumb/3141793i',
  #         ]
  #        when 5
  #         p ">>>>>>>>>>>> 5!"
  #         [
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://ustat.pashaoku.jp/auction/547743/0/L_d542a520-7a94-4cc4-a5fc-483c25fbcb50',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg',
  #           'http://lohas.nicoseiga.jp/thumb/3141793i'
  #         ]
  #        when 4
  #         p ">>>>>>>>>>>> 4!"
  #         [
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://ustat.pashaoku.jp/auction/547743/0/L_d542a520-7a94-4cc4-a5fc-483c25fbcb50',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg'
  #         ]
  #        else
  #         p ">>>>>>>>>>>> else!"
  #         [
  #           'http://22448866.up.seesaa.net/image/E8A68BE3819BE381AAE3828CE381AAE38184E38288EFBC81EFBC81.png',
  #           'http://lohas.nicoseiga.jp//thumb/3109424i',
  #           'http://blog-imgs-36.fc2.com/a/p/g/apg/201302112.jpg'
  #         ]
  #        end

  content_type :json
  map = {urls: urls}
  map[:max_id] = result[:max_id].to_s if result[:max_id]
  map[:error] = result[:error] if !result[:error].empty?
  map.to_json
end

get "/download" do
  count = get_count(params)
  max_id = get_max_id(params)
  result = get_favorited_images(client, count, max_id)

  json = {}
  json[:saved_images] = {}
  json[:existed_images] = {}
  json[:max_id] = result[:data][result[:data].size - 1].id - 1 if result[:data].size > 0
  result[:data].each do |e|
    e.media.each_index do |i|
      url = e.media[i].media_url
      idx = sprintf("%02d",i)
      filename = "#{e.id}_#{idx}" + File.extname(url)
      p filename
      dirname = File.join(File.dirname(__FILE__), settings.download_dir, e.user.id.to_s)
      FileUtils.mkdir_p(dirname) unless FileTest.exist?(dirname)

      filepath = File.join(dirname, filename)
      if FileTest.exist?(filepath)
        json[:existed_images][e.id] = filename
      else
        open(File.join(dirname, filename), 'wb') do |output|
          open(url) do |d|
            output.write(d.read)
          end
          json[:saved_images][e.id] = filename
        end
      end
    end
  end

  content_type :json
  json.to_json
end

helpers do
  def get_favorited_images(client, count, max_id)
    result = []
    error = []
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
        error << "TooManyRequests"
        p e.backtrace.join["\n"]
        break
      end

      break if !data || data.empty?

      data.each do |entity|
        result << entity if entity.media?
      end

      max_id = data[data.size-1].id - 1
    end

    return {data: result, max_id: max_id, error: error.uniq.compact}
  end

  def get_count(params)
    [[(params[:count].to_i || 20), 100].min, 1].max
  end

  def get_max_id(params)
    (params[:max_id] ? params[:max_id].to_i : nil)
  end
end
