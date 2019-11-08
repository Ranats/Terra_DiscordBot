#windows用
#::RBNACL_LIBSODIUM_GEM_LIB_PATH = "c:/msys64/mingw64/bin/libsodium-23.dll"

require 'discordrb'
require 'dotenv'
#require 'rest-client'
#require 'json'
### Google Cloud Platform APIs
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/compute_v1'

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


bot.command :hello do |event|
  event.send_message("Hello, #{event.user.name}")
end

bot.command :start do |event|
  begin
    event.send_message("Order to: Start server")

    res = client.start_instance( payload[:project], payload[:zone], payload[:resourceId] )

    event.send_message("Server starting ...")

    res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])

    while res_status.status != "RUNNING"
      sleep 1
      res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
      p res_status.status
    end

    event.send_message("Server is running.")

  rescue => e
    p e
  end
end

bot.command :stop do |event|
  begin
    event.send_message("Order to: Stop server")
    res = client.stop_instance( payload[:project], payload[:zone], payload[:resourceId] )

    event.send_message("Server stopping ...")

    res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])

    while res_status.status != "TERMINATED"
      sleep 1
      res_status = client.get_instance( payload[:project], payload[:zone], payload[:resourceId])
      p res_status.status
    end

    event.send_message("Server is stopped.")
  rescue => e
    p e
  end

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