require 'matrix'

module Ed
  class FourInLine

    def self.prepare_game
      player = ARGV.first || "Computer"
      player_a = Ed::Player.new("Computer", 1)
      player_b = Ed::Player.new(player, 2)
      # This difficulty is based on the values set to score the MAX and MIN moves
      # I find out that if the MIN value is greater than the MAX value the results are more deffensive towards the opponent move
      puts "Difficulty: (1)-Easy (2)-Normal (3)-Hard"
      diff = $stdin.readline()
      #Sets board size
      puts "Size: 21, 14, 7"
      size = $stdin.readline()
      #Creates a game instance
      game = Ed::Game.new(player_a, player_b, size.to_i, diff.to_i)
    end

    def self.play(game, turn=0, player_flag=0)
      system("clear")
      game.current_player = game.players[player_flag]
      puts "Turn: #{turn + 1} - Current player: #{game.current_player.number}"
      if game.current_player.type == "Human" || game.current_player.type == "human" 
        game.current_board.print
        puts "Suggested moves: #{game.minimax.to_s}"
        puts "What is your move? Ex: 0,1"
        line = $stdin.readline()
        move = line.split(",").map { |s| s.to_i }
        game.make move, game.current_player
      else
        move = game.minimax.first
        game.make move, game.current_player
        game.current_board.print
      end
      if game.current_board.is_over? game.current_player || game.current_board.is_tied?
        system("clear")
        puts "Turn: #{turn + 1} - Current player: #{game.current_player.number}"
        game.current_board.print
        puts "Game Over, Player #{game.current_player.number} wins"
        return true
      end
      player_flag = player_flag == 1 ? 0 : 1
      turn += 1
      play game, turn, player_flag
    end
  end

  # This class is in charge to manage the current game state, make moves, manage the current player, recommend a move based on the current state.
  class Game
    attr_accessor :player_a, :player_b, :size, :initial_state, :current_board, :current_player, :difficulty
    
    def initialize(player_a, player_b, size, difficulty=1)
      @player_a = player_a
      @player_b = player_b
      @initial_state = Ed::Board.new(size,size,nil,player_a, difficulty)
      @current_board = @initial_state
      @current_player = @player_a
      @difficulty = difficulty
    end

    def players
      [player_a, player_b]
    end

    def other_player
      current_players = players
      current_players.reject { |p| p == current_player }.first
    end

    def reset_game
      current_board = initial_state
    end

    def make move, player
      new_board_with_move = Matrix.build(current_board.state.row_size, current_board.state.column_size) do |row, col|
        if [row, col] == move
          player.number
        else
          current_board.state[row, col] 
        end
      end
      self.current_board.state = new_board_with_move
      self
    end

    def build_board_with_state board, move, player
      new_board_with_move = Matrix.build(board.state.row_size, board.state.column_size) do |row, col|
        if [row, col] == move
          player.number
        else
          board.state[row, col] 
        end
      end
      Ed::Board.new nil, nil, new_board_with_move, current_player, difficulty
    end

    def get_available_moves_by_player board, player
      available_moves, available_boards = [], []
      board.state.each_with_index do |value, row, col|
        available_moves << [row, col] if ((row - 1) < 0 && value == false) || (board.state[(row - 1), col] != false && value == false)
      end
      available_moves.each do |move|
        available_boards << build_board_with_state(board, move, player)
      end
      {available_boards: available_boards, available_moves: available_moves}
    end

    def minimax
      # Get all available moves for the current board
      available_board_moves = get_available_moves_by_player current_board, current_player
      # Score all the boards for the current player. This are the MAX values.
      max_values = score_for_boards available_board_moves, current_player
      # Initialize arrays to analize all the second moves. MIN values.
      available_board_moves_for_second_move = []
      min_values = []
      # For each available move for the current player we calculate the move that will have the most value for the second player.
      available_board_moves[:available_boards].each_with_index do |board, index|
        min_values << max_value_min_move(score_for_boards get_available_moves_by_player(board, other_player), other_player)
      end
      # Here we calculate what move will have more value for the current player depending on the result of MAX-MIN values.
      final_move = real_value_move max_values, min_values
      # Return the recommended moves, the first is the most remcommded by the minimax algorithim, the second and third moves correspond to the MAX and MIN moves. 
      # For Computer vs Computer is going to use the first recommendation, setting this option to 'random' creates cool results.
      ([final_move[:max_value_move]] + [max_value_min_move(max_values)[:max_value_move]] + min_values.map {|m| m[:max_value_move]}).uniq
    end

    def score_for_boards available_board_moves, player
      scores = []
      available_board_moves[:available_boards].each do |board|
        scores << board.get_score(player)
      end
      available_board_moves.merge!({scores: scores})
    end

    def max_value_min_move available_board_moves
      max_board_value = -100
      max_value_move = nil
      available_board_moves[:scores].each_with_index do |value, index|
        if value > max_board_value
          max_board_value = value
          max_value_move = available_board_moves[:available_moves][index]
        end
      end
      {max_board_value: max_board_value, max_value_move: max_value_move}
    end

    def real_value_move max_values, min_values
      min_values.each_with_index do |value, index|
        max_values[:scores][index] = max_values[:scores][index] - value[:max_board_value]
      end
      max_value_min_move max_values
    end

  end
  # This class is in charge of handling a state from the board, and get the different scores depending on the differnt possible winning moves
  class Board
    attr_accessor :row_count, :column_count, :state, :selected_move, :current_player, :difficulty

    def initialize(row_count=nil, column_count=nil, state=nil, current_player=nil, difficulty=nil)
      @row_count = row_count || state.row_count
      @colum_count = column_count || state.column_count
      @state = state || Matrix.build(@row_count, @colum_count) {|row, col| false}
      @current_player = current_player
      @difficulty = difficulty
    end

    def print
      (0..(@row_count-1)).to_a.reverse.each do |row_number|
        puts "Row #{row_number}: #{state.row(row_number).map {|item| item == false ? "-" : (item == 1 ? item.to_s.red : item.to_s.green)}.to_s.gsub("Vector", "")}"
      end
    end

    def is_over? player
      result = get_score(player) == (get_difficulty[0] * 4) || get_score(player) == (get_difficulty[1] * 4) ? true : false
    end

    def is_tied?
      board.each do |space|
        if space == false
          return false 
        else
          return true
        end
      end
    end

    def get_score player
      scores = []
      scores << horizontal_line_score(player)
      scores << vertical_line_score(player)
      scores << diagonal_right_line_score(player)
      scores << diagonal_left_line_score(player)
      scores.max
    end

    def horizontal_line_score player
      piece_value = player == current_player ? get_difficulty[0] : get_difficulty[1]
      score = 0
      score_to_analize = 0
      state.each_with_index do |value, row, col|
        if value == player.number
          (0..3).to_a.each do |time|
            score_to_analize += piece_value if state[row, col + time] == player.number && col + time <= state.column_count
          end
        end
        if score_to_analize > score
          score = score_to_analize
          score_to_analize = 0
        else
          score_to_analize = 0
        end
      end
      score
    end

    def vertical_line_score player
      piece_value = player == current_player ? get_difficulty[0] : get_difficulty[1]
      score = 0
      score_to_analize = 0
      state.each_with_index do |value, row, col|
        if value == player.number
          (0..3).to_a.each do |time|
            score_to_analize += piece_value if state[row + time, col] == player.number && row + time <= state.row_count
          end
        end
        if score_to_analize > score
          score = score_to_analize
          score_to_analize = 0
        else
          score_to_analize = 0
        end
      end
      score
    end

    def diagonal_right_line_score player
      piece_value = player == current_player ? get_difficulty[0] : get_difficulty[1]
      score = 0
      score_to_analize = 0
      state.each_with_index do |value, row, col|
        if value == player.number
          (0..3).to_a.each do |time|
            score_to_analize += piece_value if state[row + time, col + time] == player.number && row + time <= state.row_count && col + time <= state.column_count
          end
        end
        if score_to_analize > score
          score = score_to_analize
          score_to_analize = 0
        else
          score_to_analize = 0
        end
      end
      score
    end


    def diagonal_left_line_score player
      piece_value = player == current_player ? get_difficulty[0] : get_difficulty[1]
      score = 0
      score_to_analize = 0
      state.each_with_index do |value, row, col|
        if value == player.number
          (0..3).to_a.each do |time|
            score_to_analize += piece_value if state[row + time, col - time] == player.number && row + time <= state.row_count && col - time >= 0
          end
        end
        if score_to_analize > score
          score = score_to_analize
          score_to_analize = 0
        else
          score_to_analize = 0
        end
      end
      score
    end

    def get_difficulty 
      case difficulty
      when 1
        return easy
      when 2
        return normal
      when 3
        return hard
      end
    end

    def easy
      [5,4]
    end

    def normal
      [5,5]
    end

    def hard
      [5,6]
    end

  end

  class Player
    attr_accessor :type, :number
    
    def initialize(type, number)
      @type = type
      @number = number
    end
  end
end

# This is just to color the results
class String

  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

end
#Main execution of file
game = Ed::FourInLine.prepare_game()
Ed::FourInLine.play(game)