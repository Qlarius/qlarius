class MediaPieceType < ApplicationRecord
  has_many :media_pieces
  has_many :media_piece_phases
end
