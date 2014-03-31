module Propellor.Property where

import System.Directory
import Control.Monad
import Data.Monoid

import Propellor.Types
import Propellor.Engine
import Utility.Monad

makeChange :: IO () -> IO Result
makeChange a = a >> return MadeChange

noChange :: IO Result
noChange = return NoChange

-- | Combines a list of properties, resulting in a single property
-- that when run will run each property in the list in turn,
-- and print out the description of each as it's run. Does not stop
-- on failure; does propigate overall success/failure.
propertyList :: Desc -> [Property] -> Property
propertyList desc ps = Property desc $ ensureProperties' ps

-- | Combines a list of properties, resulting in one property that
-- ensures each in turn, stopping on failure.
combineProperties :: [Property] -> Property
combineProperties ps = Property desc $ go ps NoChange
  where
  	go [] rs = return rs
	go (l:ls) rs = do
		r <- ensureProperty l
		case r of
			FailedChange -> return FailedChange
			_ -> go ls (r <> rs)
	desc = case ps of
		(p:_) -> propertyDesc p
		_ -> "(empty)"

-- | Makes a perhaps non-idempotent Property be idempotent by using a flag
-- file to indicate whether it has run before.
-- Use with caution.
flagFile :: Property -> FilePath -> Property
flagFile property flagfile = Property (propertyDesc property) $
	go =<< doesFileExist flagfile
  where
	go True = return NoChange
	go False = do
		r <- ensureProperty property
		when (r == MadeChange) $
			writeFile flagfile ""
		return r

--- | Whenever a change has to be made for a Property, causes a hook
-- Property to also be run, but not otherwise.
onChange :: Property -> Property -> Property
property `onChange` hook = Property (propertyDesc property) $ do
	r <- ensureProperty property
	case r of
		MadeChange -> do
			r' <- ensureProperty hook
			return $ r <> r'
		_ -> return r

-- | Indicates that the first property can only be satisfied once
-- the second is.
requires :: Property -> Property -> Property
x `requires` y = combineProperties [y, x] `describe` propertyDesc x

describe :: Property -> Desc -> Property
describe p d = p { propertyDesc = d }

(==>) :: Desc -> Property -> Property
(==>) = flip describe
infixl 1 ==>

-- | Makes a Property only be performed when a test succeeds.
check :: IO Bool -> Property -> Property
check c property = Property (propertyDesc property) $ ifM c
	( ensureProperty property
	, return NoChange
	)
