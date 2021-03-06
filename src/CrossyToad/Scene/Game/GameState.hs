{-# LANGUAGE TemplateHaskell #-}

module CrossyToad.Scene.Game.GameState where

import Control.Lens
import Linear.V2

import CrossyToad.Scene.Game.Toad as Toad
import CrossyToad.Scene.Game.Car
import CrossyToad.Scene.Game.SpawnPoint

data GameState = GameState
  { __toad :: !Toad
  , __cars :: ![Car]
  , __spawnPoints :: ![SpawnPoint]
  } deriving (Eq, Show)

makeClassy ''GameState

instance HasToad GameState where
  toad = _toad

instance HasCars GameState where
  cars = _cars

instance HasSpawnPoints GameState where
  spawnPoints = _spawnPoints

initialGameState :: GameState
initialGameState = GameState
  { __toad = Toad.mk (V2 0 0)
  , __cars = []
  , __spawnPoints = []
  }
