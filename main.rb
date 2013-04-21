require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'

set :sessions, true

# Constants section

SUITS = %w[hearts spades clubs diamonds]
VALUES = %w[2 3 4 5 6 7 8 9 10 jack queen king ace]
BLACKJACK = 21
DEALER_LIM = 17

# Generic card game classes

class Card
  attr_reader :value, :suit

  def initialize(value, suit)
    @value = value
    @suit = suit
  end

  def to_s
    "#{@value} of #{@suit}"
  end
end

class Deck
  def initialize
    @deck = []
    SUITS.each { |s| VALUES.each { |v| @deck << Card.new(v, s) }}
    @deck.shuffle!
  end

  def deal
    @deck.pop
  end
end

class Player
  attr_reader :name, :hand

  def initialize(name)
    @name = name
    @hand = []
  end

  def <<(new_card)
    @hand << new_card
  end

  def value
    @hand.size
  end
end

# Blackjack classes

class BJPlayer < Player
  def value
    arr = @hand.map{|c| c.value }
    total = 0

    arr.each do |value|
      if value == "ace"
        total += 11
      elsif value.to_i == 0
        total += 10
      else
        total += value.to_i
      end
    end

    arr.select{|e| e == "ace"}.count.times { total -= 10 if total > 21 }

    total
  end

  def blackjack?
    self.value == BLACKJACK
  end

  def busted?
    self.value > BLACKJACK
  end
end

class BJDealer < BJPlayer
  def must_play?
    self.value < DEALER_LIM
  end
end

# Web App

get '/' do
  if params['playername']
    redirect '/start'
  else
    redirect '/set_player_name'
  end
end

get '/set_player_name' do
  erb :set_player_name
end

post '/set_player_name' do
  session[:player_name] = params['playername']
  redirect '/start'
end

get '/start' do
  session[:player] = BJPlayer.new(session[:player_name])
  session[:dealer] = BJDealer.new("Dealer")
  session[:deck] = Deck.new

  session[:player] << session[:deck].deal
  session[:dealer] << session[:deck].deal
  session[:player] << session[:deck].deal
  session[:dealer] << session[:deck].deal

  if session[:player].blackjack?
    session[:stage] = 'endgame'
    erb :play
  else
    session[:stage] = 'play'
    erb :play
  end
end

post '/player_round' do
  if params['hitstay'] == 'stay'
    redirect '/dealer_round'
  else
    session[:player] << session[:deck].deal
  end

  if session[:player].blackjack? || session[:player].busted?
    session[:stage] = 'endgame'
    erb :play
  else
    session[:stage] = 'play'
    erb :play
  end
end

get '/dealer_round' do
  if session[:dealer].blackjack?
    session[:stage] = 'endgame'
    erb :play
  else
    while session[:dealer].must_play?
      session[:dealer] << session[:deck].deal
    end
  end

  if session[:dealer].blackjack? || session[:dealer].busted?
    session[:stage] = 'endgame'
    erb :play
  else
    redirect '/showdown'
  end
end

get '/showdown' do
  session[:stage] = 'showdown'
  erb :play
end

post '/play_again' do
  if params['playagain'] == 'yes'
    temp = session[:player_name]
    session.clear
    session[:player_name] = temp
    redirect '/start'
  else
    erb :bye
  end
end