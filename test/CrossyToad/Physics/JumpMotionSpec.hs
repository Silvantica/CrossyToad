{-# LANGUAGE TemplateHaskell #-}

module CrossyToad.Physics.JumpMotionSpec where

import Control.Lens
import Linear.V2

import Test.Tasty.Hspec

import CrossyToad.Physics.Direction
import CrossyToad.Physics.JumpMotion
import CrossyToad.Physics.Position
import CrossyToad.Effect.Time.Timer (HasTimer(..))
import qualified CrossyToad.Effect.Time.Timer as Timer

data Ent = Ent
  { __position :: Position
  , __jumpMotion :: JumpMotion
  } deriving (Eq, Show)

makeClassy ''Ent

instance HasPosition Ent where
  position = _position

instance HasJumpMotion Ent where
  jumpMotion = _jumpMotion

initialJumpMotion :: JumpMotion
initialJumpMotion = mk East 0 0 0.15

stationaryEnt :: Ent
stationaryEnt = Ent
  { __position = V2 0 0
  , __jumpMotion = initialJumpMotion
  }

movingEnt :: Ent
movingEnt = stationaryEnt & jumpMotion .~ movingMotion

movingMotion :: JumpMotion
movingMotion = initialJumpMotion
  { _speed = 1
  , _targetDistance = 32
  }

spec_Physics_JumpMotion :: Spec
spec_Physics_JumpMotion = do
  describe "jump" $ do
    it "should not jump if we are already moving" $ do
      let motion' = movingMotion & (direction .~ East)
      (jump West motion') `shouldBe` motion'

    it "should not jump if we are cooling down" $ do
      let motion' = initialJumpMotion & (cooldown %~ Timer.start)
      (jump East motion') `shouldBe` motion'

    it "should update the target distance if we are not moving" $ do
      let distance' = (jump (movingMotion^.direction) initialJumpMotion)^.targetDistance
      distance' `shouldBe` initialJumpMotion^.distance

    it "should update the direction if we are not moving" $ do
      let motion' = initialJumpMotion & (direction .~ East)
      let direction' = (jump West motion') ^. direction
      direction' `shouldBe` West

  describe "isMoving" $ do
    it "should be true when we are moving" $ isMoving movingMotion `shouldBe` True
    it "should be false when we are stationary" $ isMoving initialJumpMotion `shouldBe` False

  describe "stepBy" $ do
    let stepBy' = stepBy 1
    context "should move the entity such that it" $ do
      it "changes position based on speed" $ do
        let ent' = movingEnt & jumpMotion %~ (speed .~ 2)
                                           . (targetDistance .~ 3)
                                           . (direction .~ East)
        (stepBy' ent') ^. position `shouldBe` (V2 2 0)

      it "stops at the target distance when the speed exceeds the distance" $ do
        let ent' = movingEnt & jumpMotion %~ (speed .~ 2)
                                           . (targetDistance .~ 1)
                                           . (direction .~ East)
        (stepBy' ent') ^. position `shouldBe` (V2 1 0)

      it "moves by the speed of the motion" $ do
        let ent' = movingEnt & jumpMotion %~ (speed .~ 2)
                                           . (targetDistance .~ 5)
                                           . (direction .~ East)
        (stepBy' ent') ^. position `shouldBe` (V2 2 0)

      it "does nothing when the speed is 0" $ do
        let ent' = movingEnt & (jumpMotion.speed .~ 0)
        stepBy' ent' `shouldBe` ent'

      it "does nothing when the target distance is 0" $ do
        let ent' = movingEnt & (jumpMotion.targetDistance .~ 0)
        stepBy' ent' `shouldBe` ent'

    it "should reduce the target distance by the travelled distance" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 5)
                                         . (targetDistance .~ 11)
      (stepBy' ent') ^. targetDistance `shouldBe` 6

    it "should not reduce the target distance below 0" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 5)
                                         . (targetDistance .~ 4.9)
      (stepBy' ent') ^. targetDistance `shouldBe` 0

    it "should linearize the result against the delta time" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 10)
                                         . (targetDistance .~ 10)
                                         . (direction .~ East)
      let delta = 0.1
      (stepBy delta ent') ^. position `shouldBe` (V2 1 0)

    it "should not linearize target distance" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 320)
                                         . (targetDistance .~ 32)
                                         . (direction .~ East)
      let delta = 0.05
      (stepBy delta ent') ^. position `shouldBe` (V2 16 0)

    it "should update the target distance by the linearized amount" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 20)
                                         . (targetDistance .~ 10)
                                         . (direction .~ East)
      let delta = 0.05
      (stepBy delta ent') ^. targetDistance `shouldBe` 9

    it "should reduce the current cooldown by the delta" $ do
      let ent' = movingEnt & jumpMotion %~ (cooldown.currentTime .~ 2)
      (stepBy' ent') ^. cooldown.currentTime `shouldBe` 1

    it "should linearize the result against the remaining delta time after cooldown" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 10)
                                         . (targetDistance .~ 10)
                                         . (direction .~ East)
                                         . (cooldown.currentTime .~ 0.1)
      let delta = 0.2
      (stepBy delta ent') ^. position `shouldBe` (V2 1 0)

    it "should begin cooling down when finishing a jump" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 10)
                                         . (targetDistance .~ 5)
                                         . (cooldown.startTime .~ 0.2)
      (stepBy 1 ent') ^. cooldown.currentTime `shouldBe` 0.2

    it "should not cooldown if a jump has not finished yet" $ do
      let ent' = movingEnt & jumpMotion %~ (speed .~ 10)
                                         . (targetDistance .~ 11)
                                         . (cooldown.currentTime .~ 0.2)
      (stepBy 1 ent') ^. cooldown.currentTime `shouldBe` 0
