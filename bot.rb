#windows用
::RBNACL_LIBSODIUM_GEM_LIB_PATH = "c:/msys64/mingw64/bin/libsodium-23.dll"

require 'discordrb'
require 'dotenv'
#require 'rest-client'
#require 'json'
### Google Cloud Platform APIs
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/compute_v1'
require 'pp'

Dotenv.load

scope = ['https://www.googleapis.com/auth/compute']
client = Google::Apis::ComputeV1::ComputeService.new
client.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open('gce-api.json'),
    scope: scope
)

payload = {
    :project => ENV["PROJECT"],
    :zone => ENV["ZONE"],
    :resourceId => ENV["RESOURCE_ID"]
}#.to_json

bot = Discordrb::Commands::CommandBot.new(
    token: ENV["TOKEN"],
    client_id: ENV["CLIENT_ID"],
    prefix:'/',
)

### メモ
# bot.send_message ( @channel, message ) => @channel にメッセージを送る
# event.send_message (message) => event... コマンドを受け取ったならそのテキストサーバー，voice_state_updateならVoiceStateUpdateEvent，等になる

bot.ready do
  bot.game = "Megaria"
  bot.servers.each_value do |srv|
    if srv.name == "test"
      @inform_channel = srv.channels.find{|s| s.type == 0}
      @in_voice_server_people = srv.channels.find{|s| s.type == 2}.users.size
    end
  end
  p @in_voice_server_people
end

start_proc = Proc.new do |event|
  begin
    bot.send_message(@inform_channel,"Order : Start server")

    res = client.start_instance( payload[:project], payload[:zone], payload[:resourceId] )

    bot.send_message(@inform_channel,"Server starting ...")

    res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])

    while res_status.status != "RUNNING"
      sleep 1
      res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
      p res_status.status
    end

    status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
    address = status.network_interfaces.first.access_configs.first.nat_ip

    message = "Server is running at #{address}"

    bot.send_message(@inform_channel,message)

  rescue => e
    p e
  end
end

stop_proc = Proc.new do |event|
  begin
    bot.send_message(@inform_channel,"Order : Stop server")
    res = client.stop_instance( payload[:project], payload[:zone], payload[:resourceId] )

    bot.send_message(@inform_channel, "Server stopping ...")

    res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])

    while res_status.status != "TERMINATED"
      sleep 1
      res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
      p res_status.status
    end

    bot.send_message(@inform_channel,"Server is stopped.")
  rescue => e
    p e
  end
end

bot.command :hello do |event|
  event.send_message("Hello, #{event.user.name}")
  event.send_message("/Help でコマンド一覧を表示")
end

# voice_channnelへの入退室を検知して発火
bot.voice_state_update do |event|
  user = event.user.name

  if event.channel.nil?
    if event.old_channel.users.size < 1
      p "left #{user} from #{event.old_channel.name}"
      bot.send_message(@inform_channel, "誰もおらんくなったのでサーバーを止めるマン")
      @in_voice_server_people -= 1
    end
#    stop_proc.call(event)
  else
    if event.channel.users.size > @in_voice_server_people
      p "join #{user} to #{event.channel.name}"
      bot.send_message(@inform_channel,"#{user} is joined #{event.channel.name}")
      @in_voice_server_people += 1
    end

  end
end

bot.command :start do |event|
  start_proc.call(event)
end

bot.command :stop do |event|
  stop_proc.call(event)
end

bot.command :status do |event|
  status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])

  event.send_message("Server is #{status.status}")
end

bot.command :addr do |event|
  status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
  event.send_message(status.network_interfaces.first.access_configs.first.nat_ip)
end

bot.command :help do |event|
  event.send_message("挨拶: /hello")
  event.send_message("サーバーの起動: /start")
  event.send_message("サーバーの停止: /stop")
  event.send_message("サーバーの状態: /status")
  event.send_message("サーバーアドレスの表示: /addr")
end

bot.run