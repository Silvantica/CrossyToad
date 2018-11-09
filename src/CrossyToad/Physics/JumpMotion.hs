{-# LANGUAGE TemplateHaskell #-}

-- | Describes a method of travel where the entity "jumps" from one position to another.
-- |
-- | Jumps are not instant and can vary in speed and distance. Also: If the entity is already
-- | jumping it will not be able to jump again until it completes the original jump.
module CrossyToad.Physics.JumpMotion
  ( JumpMotion(..)
  , HasJumpMotion(..)
  , initialJumpMotion
  , stepJumpMotion
  , jump
  , isMoving
  ) where

import Control.Lens
import Control.Monad (when)
import Control.Monad.State (MonadState)
import Linear.V2

import CrossyToad.Time.Time
import CrossyToad.Physics.Direction
import CrossyToad.Physics.Distance
import CrossyToad.Physics.Speed

data JumpMotion = JumpMotion
  { __direction :: Direction     -- ^ What direction we are facing

  , _speed :: Speed              -- ^ How fast we can move
  , _distance :: Distance        -- ^ How far we move in a single jump
  , _cooldown :: Seconds         -- ^ How much time must elapse between jumps

  , _currentCooldown :: Seconds  -- ^ How much time until we can perform our next jump
  , _targetDistance :: Distance  -- ^ How far we _are_ moving
  } deriving (Eq, Show)

makeClassy ''JumpMotion

instance HasDirection JumpMotion where
  direction = _direction

initialJumpMotion :: JumpMotion
initialJumpMotion = JumpMotion
  { __direction = East
  , _speed = 0
  , _distance = 32
  , _cooldown = 0
  , _currentCooldown = 0
  , _targetDistance = 0
  }


-- | Jump towards the direction we are facing. This affects the motion vector
-- | returned by @stepJumpMotion@
-- |
-- | If we are already moving this function will change nothing.
-- | If we are currently cooling down this function will change nothing.
jump :: Direction -> JumpMotion -> JumpMotion
jump dir motion | canJump motion = motion & (direction .~ dir)
                                          . (targetDistance .~ motion^.distance)
                | otherwise = motion

canJump :: JumpMotion -> Bool
canJump motion = (not $ isCoolingDown motion) && (not $ isMoving motion)

isCoolingDown :: JumpMotion -> Bool
isCoolingDown motion = (motion^.currentCooldown > 0)

isMoving :: JumpMotion -> Bool
isMoving motion = (motion^.targetDistance > 0)

-- | Returns the motion vector for this frame and updates the motion.
stepJumpMotion :: (MonadState s m, HasJumpMotion s) => Seconds -> m (V2 Float)
stepJumpMotion delta = do
  jumpDelta <- stepCooldown delta
  stepJump jumpDelta

stepJump :: (MonadState s m, HasJumpMotion s) => Seconds -> m (V2 Float)
stepJump delta = do
  motion' <- use jumpMotion

  -- TODO: Figure out how to write this better
  if (isMoving motion')
    then do
      let (motionVector', distanceThisFrame) = motionVectorOverTime delta motion'
      let nextDistance = max 0 (motion' ^. targetDistance) - distanceThisFrame

      jumpMotion.targetDistance .= nextDistance

      when (nextDistance == 0) stepMovementFinished

      pure motionVector'
    else
      pure (V2 0 0)

-- | Steps to run when a jump finishes
stepMovementFinished :: (MonadState s m, HasJumpMotion s) => m ()
stepMovementFinished = do
  motion' <- use jumpMotion
  jumpMotion.currentCooldown .= (motion' ^. cooldown)

-- | Steps the cooldown for this frame and returns any remaining delta time.
-- |
-- | The idea is that if the cooldown consumes some of the delta time, the remaining
-- | delta time is still available to the entity to make a short jump.
stepCooldown :: (MonadState s m, HasJumpMotion s) => Seconds -> m Seconds
stepCooldown delta = do
  currentCooldown' <- use (jumpMotion.currentCooldown)
  let nextCooldown = currentCooldown' - delta
  let remainingDelta = abs nextCooldown
  jumpMotion.currentCooldown .= max 0 nextCooldown
  pure remainingDelta

-- | Calculate the motion vector and distance to travel from the current
-- | motion.
motionVectorOverTime :: Seconds -> JumpMotion -> (V2 Float, Distance)
motionVectorOverTime delta motion' =
  let scaledVelocity = (motion' ^. speed) * delta
      distanceThisFrame = min (scaledVelocity) (motion' ^. targetDistance)
      directionVector = unitVector $ motion' ^. direction
      motionVector' = (* distanceThisFrame) <$> directionVector
  in (motionVector', distanceThisFrame)
