require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'

set :sessions, true

# Constants section

SUITS = %w[hearts spades clubs diamonds]
VALUES = %w[2 3 4 5 6 7 8 9 10 jack queen king ace]
BLACKJACK = 21
DEALER_LIM = 17
PLAYER_AMOUNT = 500
DEALER_AMOUNT = 100000

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
  attr_reader :name, :hand, :amount

  def initialize(name, amount)
    @name = name
    @amount = amount
    @hand = []
  end

  def <<(new_card)
    @hand << new_card
  end

  def value
    @hand.size
  end

  def bet(pot)
    @amount -= pot
  end

  def win(pot)
    @amount += pot
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

helpers do
  def show_card(card)
    "<img src='/images/cards/#{card.suit}_#{card.value}.jpg' class=card_image >"
  end

  def player_win
    session[:player].win(2*session[:bet])
    session[:player_amount] += 2* session[:bet]
  end

  def dealer_win
    session[:dealer].win(2*session[:bet])
  end

  def tie_win
    session[:player].win(session[:bet])
    session[:player_amount] += session[:bet]
    session[:dealer].win(session[:bet])
  end
end

get '/' do
  if session[:player_name]
    redirect '/start'
  else
    erb :set_player_name
  end
end

post '/set_player_name' do
  if params['player_name'].nil? || params['player_name'].empty?
    @error = "Player name must not be empty!"
    erb :set_player_name
  else
    session[:player_name] = params['player_name']
    session[:player_amount] = PLAYER_AMOUNT
    redirect '/start'
  end
end

get '/start' do
  session[:player] = BJPlayer.new(session[:player_name], session[:player_amount])
  session[:dealer] = BJDealer.new("Dealer", DEALER_AMOUNT)
  session[:deck] = Deck.new

  session[:player] << session[:deck].deal
  session[:dealer] << session[:deck].deal
  session[:player] << session[:deck].deal
  session[:dealer] << session[:deck].deal

  redirect '/bet'
end

get '/bet' do
  erb :bet
end

post '/bet' do
  if params["bet"].nil? || params["bet"].to_i == 0
    @error = "The amount must not be zero or empty"
    erb :bet
  elsif params["bet"].to_i > session[:player].amount
    @error = "The amount must not be higher than your current account"
    erb :bet
  else
    session[:bet] = params["bet"].to_i
    session[:player_amount] -= session[:bet]
    session[:player].bet(session[:bet])
    session[:dealer].bet(session[:bet])

    redirect '/player_round'
  end
end

get '/player_round' do
  if session[:player].blackjack?
    session[:stage] = 'endgame'
  else
    session[:stage] = 'play_p'
  end

  erb :play
end

post '/player_round' do
  if params['hit_stay'] == 'stay'
    session[:stage] = 'play_d'
    redirect '/dealer_round'
  elsif params['hit_stay'] == 'hit'
    session[:player] << session[:deck].deal
  else
    @error = "Hit or Stay must be selected!"
    erb :play
  end

  if session[:player].blackjack? || session[:player].busted?
    session[:stage] = 'endgame'
  else
    session[:stage] = 'play_p'
  end

  erb :play
end

get '/dealer_round' do
  if session[:dealer].blackjack?
    session[:stage] = 'endgame'
  elsif session[:dealer].must_play?
    session[:stage] = 'play_d'
  else
    session[:stage] = 'showdown'
  end

  erb :play
end

post '/dealer_round' do
  session[:dealer] << session[:deck].deal

  if session[:dealer].blackjack? || session[:dealer].busted?
    session[:stage] = 'endgame'
  elsif session[:dealer].must_play?
    session[:stage] = 'play_d'
  else
    session[:stage] = 'showdown'
  end

  erb :play
end

post '/play_again' do
  if params['play_again'] == 'yes' && session[:player_amount] != 0
    temp_n = session[:player].name
    temp_a = session[:player].amount
    session.clear
    session[:player_name] = temp_n
    session[:player_amount] = temp_a
    redirect '/start'
  elsif params['play_again'] == 'yes' && session[:player_amount] == 0
    @error = "We know you said Yes. But you're broken..."
    erb :play
  elsif params['play_again'] == 'no'
    redirect '/quit'
  else
    @error = "Yes or No must be selected!"
    erb :play
  end
end

get '/quit' do
    session.clear
    erb :bye
end
