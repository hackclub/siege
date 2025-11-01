class WatchPartyChannel < ApplicationCable::Channel
  def subscribed
    stream_from "watch_party_channel"
  end

  def unsubscribed
  end
end
