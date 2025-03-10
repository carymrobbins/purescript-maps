module Test.Data.Map where

import Prelude

import Control.Alt ((<|>))
import Control.Monad.Eff.Console (log)
import Data.Foldable (foldl, for_)
import Data.Function (on)
import Data.List (List(..), groupBy, length, nubBy, sortBy, singleton, toList)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Tuple (Tuple(..), fst)
import Test.QuickCheck ((<?>), quickCheck, quickCheck')
import Test.QuickCheck.Arbitrary (Arbitrary, arbitrary)
import Test.QuickCheck.Gen (Gen(..))

import qualified Data.Map as M

instance arbMap :: (Eq k, Ord k, Arbitrary k, Arbitrary v) => Arbitrary (M.Map k v) where
  arbitrary = M.fromList <$> arbitrary

instance arbitraryList :: (Arbitrary a) => Arbitrary (List a) where
  arbitrary = toList <$> (arbitrary :: Gen (Array a))

data SmallKey = A | B | C | D | E | F | G | H | I | J

instance showSmallKey :: Show SmallKey where
  show A = "A"
  show B = "B"
  show C = "C"
  show D = "D"
  show E = "E"
  show F = "F"
  show G = "G"
  show H = "H"
  show I = "I"
  show J = "J"

instance eqSmallKey :: Eq SmallKey where
  eq A A = true
  eq B B = true
  eq C C = true
  eq D D = true
  eq E E = true
  eq F F = true
  eq G G = true
  eq H H = true
  eq I I = true
  eq J J = true
  eq _ _ = false

smallKeyToInt :: SmallKey -> Int
smallKeyToInt A = 0
smallKeyToInt B = 1
smallKeyToInt C = 2
smallKeyToInt D = 3
smallKeyToInt E = 4
smallKeyToInt F = 5
smallKeyToInt G = 6
smallKeyToInt H = 7
smallKeyToInt I = 8
smallKeyToInt J = 9

instance ordSmallKey :: Ord SmallKey where
  compare = compare `on` smallKeyToInt

instance arbSmallKey :: Arbitrary SmallKey where
  arbitrary = do
    n <- arbitrary
    return case n of
      _ | n < 0.1 -> A
      _ | n < 0.2 -> B
      _ | n < 0.3 -> C
      _ | n < 0.4 -> D
      _ | n < 0.5 -> E
      _ | n < 0.6 -> F
      _ | n < 0.7 -> G
      _ | n < 0.8 -> H
      _ | n < 0.9 -> I
      _ -> J

data Instruction k v = Insert k v | Delete k

instance showInstruction :: (Show k, Show v) => Show (Instruction k v) where
  show (Insert k v) = "Insert (" ++ show k ++ ") (" ++ show v ++ ")"
  show (Delete k) = "Delete (" ++ show k ++ ")"

instance arbInstruction :: (Arbitrary k, Arbitrary v) => Arbitrary (Instruction k v) where
  arbitrary = do
    b <- arbitrary
    case b of
      true -> do
        k <- arbitrary
        v <- arbitrary
        return (Insert k v)
      false -> do
        k <- arbitrary
        return (Delete k)

runInstructions :: forall k v. (Ord k) => List (Instruction k v) -> M.Map k v -> M.Map k v
runInstructions instrs t0 = foldl step t0 instrs
  where
  step tree (Insert k v) = M.insert k v tree
  step tree (Delete k) = M.delete k tree

smallKey :: SmallKey -> SmallKey
smallKey k = k

number :: Int -> Int
number n = n

mapTests = do

  -- Data.Map

  log "Test inserting into empty tree"
  quickCheck $ \k v -> M.lookup (smallKey k) (M.insert k v M.empty) == Just (number v)
    <?> ("k: " ++ show k ++ ", v: " ++ show v)

  log "Test delete after inserting"
  quickCheck $ \k v -> M.isEmpty (M.delete (smallKey k) (M.insert k (number v) M.empty))
    <?> ("k: " ++ show k ++ ", v: " ++ show v)

  log "Insert two, lookup first"
  quickCheck $ \k1 v1 k2 v2 -> k1 == k2 || M.lookup k1 (M.insert (smallKey k2) (number v2) (M.insert (smallKey k1) (number v1) M.empty)) == Just v1
    <?> ("k1: " ++ show k1 ++ ", v1: " ++ show v1 ++ ", k2: " ++ show k2 ++ ", v2: " ++ show v2)

  log "Insert two, lookup second"
  quickCheck $ \k1 v1 k2 v2 -> M.lookup k2 (M.insert (smallKey k2) (number v2) (M.insert (smallKey k1) (number v1) M.empty)) == Just v2
    <?> ("k1: " ++ show k1 ++ ", v1: " ++ show v1 ++ ", k2: " ++ show k2 ++ ", v2: " ++ show v2)

  log "Insert two, delete one"
  quickCheck $ \k1 v1 k2 v2 -> k1 == k2 || M.lookup k2 (M.delete k1 (M.insert (smallKey k2) (number v2) (M.insert (smallKey k1) (number v1) M.empty))) == Just v2
    <?> ("k1: " ++ show k1 ++ ", v1: " ++ show v1 ++ ", k2: " ++ show k2 ++ ", v2: " ++ show v2)

  log "Check balance property"
  quickCheck' 5000 $ \instrs ->
    let
      tree :: M.Map SmallKey Int
      tree = runInstructions instrs M.empty
    in M.checkValid tree <?> ("Map not balanced:\n  " ++ show tree ++ "\nGenerated by:\n  " ++ show instrs)

  log "Lookup from empty"
  quickCheck $ \k -> M.lookup k (M.empty :: M.Map SmallKey Int) == Nothing

  log "Lookup from singleton"
  quickCheck $ \k v -> M.lookup (k :: SmallKey) (M.singleton k (v :: Int)) == Just v

  log "Random lookup"
  quickCheck' 5000 $ \instrs k v ->
    let
      tree :: M.Map SmallKey Int
      tree = M.insert k v (runInstructions instrs M.empty)
    in M.lookup k tree == Just v <?> ("instrs:\n  " ++ show instrs ++ "\nk:\n  " ++ show k ++ "\nv:\n  " ++ show v)

  log "Singleton to list"
  quickCheck $ \k v -> M.toList (M.singleton k v :: M.Map SmallKey Int) == singleton (Tuple k v)

  log "toList . fromList = id"
  quickCheck $ \arr -> let f x = M.toList (M.fromList x)
                       in f (f arr) == f (arr :: List (Tuple SmallKey Int)) <?> show arr

  log "fromList . toList = id"
  quickCheck $ \m -> let f m = M.fromList (M.toList m) in
                     M.toList (f m) == M.toList (m :: M.Map SmallKey Int) <?> show m

  log "fromListWith const = fromList"
  quickCheck $ \arr -> M.fromListWith const arr ==
                       M.fromList (arr :: List (Tuple SmallKey Int)) <?> show arr

  log "fromListWith (<>) = fromList . collapse with (<>) . group on fst"
  quickCheck $ \arr ->
    let combine (Tuple s a) (Tuple t b) = (Tuple s $ b <> a)
        foldl1 g (Cons x xs) = foldl g x xs
        f = M.fromList <<< (<$>) (foldl1 combine) <<<
            groupBy ((==) `on` fst) <<< sortBy (compare `on` fst) in
    M.fromListWith (<>) arr == f (arr :: List (Tuple String String)) <?> show arr

  log "Lookup from union"
  quickCheck $ \m1 m2 k -> M.lookup (smallKey k) (M.union m1 m2) == (case M.lookup k m1 of
    Nothing -> M.lookup k m2
    Just v -> Just (number v)) <?> ("m1: " ++ show m1 ++ ", m2: " ++ show m2 ++ ", k: " ++ show k ++ ", v1: " ++ show (M.lookup k m1) ++ ", v2: " ++ show (M.lookup k m2) ++ ", union: " ++ show (M.union m1 m2))

  log "Union is idempotent"
  quickCheck $ \m1 m2 -> (m1 `M.union` m2) == ((m1 `M.union` m2) `M.union` (m2 :: M.Map SmallKey Int))

  log "Union prefers left"
  quickCheck $ \m1 m2 k -> M.lookup k (M.union m1 (m2 :: M.Map SmallKey Int)) == (M.lookup k m1 <|> M.lookup k m2)

  log "unionWith"
  for_ [Tuple (+) 0, Tuple (*) 1] $ \(Tuple op ident) ->
    quickCheck $ \m1 m2 k ->
      let u = M.unionWith op m1 m2 :: M.Map SmallKey Int
      in case M.lookup k u of
           Nothing -> not (M.member k m1 || M.member k m2)
           Just v -> v == op (fromMaybe ident (M.lookup k m1)) (fromMaybe ident (M.lookup k m2))

  log "unionWith argument order"
  quickCheck $ \m1 m2 k ->
    let u   = M.unionWith (-) m1 m2 :: M.Map SmallKey Int
        in1 = M.member k m1
        v1  = M.lookup k m1
        in2 = M.member k m2
        v2  = M.lookup k m2
    in case M.lookup k u of
          Just v | in1 && in2 -> Just v == ((-) <$> v1 <*> v2)
          Just v | in1        -> Just v == v1
          Just v              -> Just v == v2
          Nothing             -> not (in1 || in2)

  log "size"
  quickCheck $ \xs ->
    let xs' = nubBy ((==) `on` fst) xs
    in  M.size (M.fromList xs') == length (xs' :: List (Tuple SmallKey Int))
