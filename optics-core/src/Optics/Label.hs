-- |
-- Module: Optics.Label
-- Description: Overloaded labels as optics
--
-- Overloaded labels are a solution to Haskell's namespace problem for records.
-- The @-XOverloadedLabels@ extension allows a new expression syntax for labels,
-- a prefix @#@ sign followed by an identifier, e.g. @#foo@.  These expressions
-- can then be given an interpretation that depends on the type at which they
-- are used and the text of the label.
--
-- The following example shows how overloaded labels can be used as optics.
--
-- == Example
--
-- Consider the following:
--
-- >>> :set -XDataKinds
-- >>> :set -XFlexibleContexts
-- >>> :set -XFlexibleInstances
-- >>> :set -XMultiParamTypeClasses
-- >>> :set -XOverloadedLabels
-- >>> :set -XTypeFamilies
-- >>> :set -XUndecidableInstances
-- >>> :{
-- data Human = Human
--   { humanName :: String
--   , humanAge  :: Integer
--   , humanPets :: [Pet]
--   } deriving Show
-- data Pet
--   = Cat  { petName :: String, petAge :: Int, petLazy :: Bool }
--   | Fish { petName :: String, petAge :: Int }
--   deriving Show
-- :}
--
-- The following instances can be generated by @makeFieldLabels@ from
-- @Optics.TH@ in the @optics-th@ package:
--
-- >>> :{
-- instance (a ~ String, b ~ String) => LabelOptic "name" A_Lens Human Human a b where
--   labelOptic = lensVL $ \f s -> (\v -> s { humanName = v }) <$> f (humanName s)
-- instance (a ~ Integer, b ~ Integer) => LabelOptic "age" A_Lens Human Human a b where
--   labelOptic = lensVL $ \f s -> (\v -> s { humanAge = v }) <$> f (humanAge s)
-- instance (a ~ [Pet], b ~ [Pet]) => LabelOptic "pets" A_Lens Human Human a b where
--   labelOptic = lensVL $ \f s -> (\v -> s { humanPets = v }) <$> f (humanPets s)
-- instance (a ~ String, b ~ String) => LabelOptic "name" A_Lens Pet Pet a b where
--   labelOptic = lensVL $ \f s -> (\v -> s { petName = v }) <$> f (petName s)
-- instance (a ~ Int, b ~ Int) => LabelOptic "age" A_Lens Pet Pet a b where
--   labelOptic = lensVL $ \f s -> (\v -> s { petAge = v }) <$> f (petAge s)
-- instance (a ~ Bool, b ~ Bool) => LabelOptic "lazy" An_AffineTraversal Pet Pet a b where
--   labelOptic = atraversalVL $ \point f s -> case s of
--     Cat name age lazy -> (\lazy' -> Cat name age lazy') <$> f lazy
--     _                 -> point s
-- :}
--
-- Here is some test data:
--
-- >>> :{
-- peter :: Human
-- peter = Human "Peter" 13 [ Fish "Goldie" 1
--                          , Cat  "Loopy"  3 False
--                          , Cat  "Sparky" 2 True
--                          ]
-- :}
--
-- Now we can ask for Peter's name:
--
-- >>> view #name peter
-- "Peter"
--
-- or for names of his pets:
--
-- >>> toListOf (#pets % folded % #name) peter
-- ["Goldie","Loopy","Sparky"]
--
-- We can check whether any of his pets is lazy:
--
-- >>> orOf (#pets % folded % #lazy) peter
-- True
--
-- or how things might be be a year from now:
--
-- >>> peter & over #age (+1) & over (#pets % mapped % #age) (+1)
-- Human {humanName = "Peter", humanAge = 14, humanPets = [Fish {petName = "Goldie", petAge = 2},Cat {petName = "Loopy", petAge = 4, petLazy = False},Cat {petName = "Sparky", petAge = 3, petLazy = True}]}
--
-- Perhaps Peter is going on vacation and needs to leave his pets at home:
--
-- >>> peter & set #pets []
-- Human {humanName = "Peter", humanAge = 13, humanPets = []}
--
--
-- == Structure of 'LabelOptic' instances
--
-- You might wonder why instances above are written in form
--
-- @
-- instance (a ~ [Pet], b ~ [Pet]) => LabelOptic "pets" A_Lens Human Human a b where
-- @
--
-- instead of
--
-- @
-- instance LabelOptic "pets" A_Lens Human Human [Pet] [Pet] where
-- @
--
-- The reason is that using the first form ensures that GHC always matches on
-- the instance if either @s@ or @t@ is known and verifies type equalities
-- later, which not only makes type inference better, but also allows it to
-- generate good error messages.
--
-- For example, if you try to write @peter & set #pets []@ with the appropriate
-- LabelOptic instance in the second form, you get the following:
--
-- @
-- <interactive>:16:1: error:
--    • No instance for LabelOptic "pets" ‘A_Lens’ ‘Human’ ‘()’ ‘[Pet]’ ‘[a0]’
--        (maybe you forgot to define it or misspelled a name?)
--    • In the first argument of ‘print’, namely ‘it’
--      In a stmt of an interactive GHCi command: print it
-- @
--
-- That's because empty list doesn't have type @[Pet]@, it has type @[r]@ and
-- GHC doesn't have enough information to match on the instance we
-- provided. We'd need to either annotate the list: @peter & set #pets
-- ([]::[Pet])@ or the result type: @peter & set #pets [] :: Human@, which is
-- suboptimal.
--
-- Here are more examples of confusing error messages if the instance for
-- @LabelOptic "age"@ is written without type equalities:
--
-- @
-- λ> view #age peter :: Char
--
-- <interactive>:28:6: error:
--     • No instance for LabelOptic "age" ‘k0’ ‘Human’ ‘Human’ ‘Char’ ‘Char’
--         (maybe you forgot to define it or misspelled a name?)
--     • In the first argument of ‘view’, namely ‘#age’
--       In the expression: view #age peter :: Char
--       In an equation for ‘it’: it = view #age peter :: Char
-- λ> peter & set #age "hi"
--
-- <interactive>:29:1: error:
--     • No instance for LabelOptic "age" ‘k’ ‘Human’ ‘b’ ‘a’ ‘[Char]’
--         (maybe you forgot to define it or misspelled a name?)
--     • When checking the inferred type
--         it :: forall k b a. ((TypeError ...), Is k A_Setter) => b
-- @
--
-- If we use the first form, error messages become more accurate:
--
-- @
-- λ> view #age peter :: Char
-- <interactive>:31:6: error:
--     • Couldn't match type ‘Char’ with ‘Integer’
--         arising from the overloaded label ‘#age’
--     • In the first argument of ‘view’, namely ‘#age’
--       In the expression: view #age peter :: Char
--       In an equation for ‘it’: it = view #age peter :: Char
-- λ> peter & set #age "hi"
--
-- <interactive>:32:13: error:
--     • Couldn't match type ‘[Char]’ with ‘Integer’
--         arising from the overloaded label ‘#age’
--     • In the first argument of ‘set’, namely ‘#age’
--       In the second argument of ‘(&)’, namely ‘set #age "hi"’
--       In the expression: peter & set #age "hi"
-- @
--
-- == Limitations arising from functional dependencies
--
-- Functional dependencies guarantee good type inference, but also
-- create limitations. We can split them into two groups:
--
-- - @name s -> k a@, @name t -> k b@
--
-- - @name s b -> t@, @name t a -> s@
--
-- The first group ensures that when we compose two optics, the middle type is
-- unambiguous. The consequence is that it's not possible to create label optics
-- with @a@ or @b@ referencing type variables not referenced in @s@ or @t@,
-- i.e. getters for fields of rank 2 type or reviews for constructors with
-- existentially quantified types inside.
--
-- The second group ensures that when we perform a chain of updates, the middle
-- type is unambiguous. The consequence is that it's not possible to define
-- label optics that:
--
-- - Modify phantom type parameters of type @s@ or @t@.
--
-- - Modify type parameters of type @s@ or @t@ if @a@ or @b@ contain ambiguous
--   applications of type families to these type parameters.
--
module Optics.Label
  ( LabelOptic(..)
  , LabelOptic'
  ) where

import Optics.Internal.Optic

-- $setup
-- >>> import Optics.Core
