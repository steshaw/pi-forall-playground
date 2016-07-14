{- PiForall language, OPLSS -}

{-# LANGUAGE TemplateHaskell,
             FlexibleInstances, 
             MultiParamTypeClasses, 
             FlexibleContexts, 
             UndecidableInstances, 
             ViewPatterns, 
             EmptyDataDecls,
             DeriveGeneric,
             DeriveDataTypeable,
             CPP #-}

{-# OPTIONS_GHC -Wall -fno-warn-unused-matches -fno-warn-orphans #-}



-- | The abstract syntax of the simple dependently typed language
-- See comment at the top of 'Parser' for the concrete syntax

module Syntax where


#ifdef MIN_VERSION_GLASGOW_HASKELL
#if MIN_VERSION_GLASGOW_HASKELL(7,10,3,0)
-- ghc >= 7.10.3
#else
-- older ghc versions, but MIN_VERSION_GLASGOW_HASKELL defined
#endif
#else
-- MIN_VERSION_GLASGOW_HASKELL not even defined yet (ghc <= 7.8.x)

-- both needed only on even earlier ghc's
-- import Control.Applicative (pure)
-- import Data.Monoid (mempty)
#endif


import GHC.Generics (Generic)
import Data.Typeable (Typeable)

import Unbound.Generics.LocallyNameless
-- import Unbound.Generics.LocallyNameless.Unsafe (unsafeUnbind)
import Unbound.Generics.LocallyNameless.TH (makeClosedAlpha)
import Text.ParserCombinators.Parsec.Pos       
-- import Data.Set (Set)
-- import qualified Data.Set as S
import Data.Maybe (fromMaybe)

-----------------------------------------
-- * Variable names
-----------------------------------------

-- | term names, use unbound library to 
-- automatically generate fv, subst, alpha-eq
type TName = Name Term

-- | module names
type MName  = String

-- | type constructor names
type TCName = String

-- | data constructor names
type DCName = String

-----------------------------------------
-- * Core language
-----------------------------------------


-- Type abbreviation for documentation
type Type = Term

data Term = 
   -- basic language
     Type                               -- ^ type of types
   | Var TName                          -- ^ variables      
   | Lam (Bind (TName, Embed Annot) Term)
                                        -- ^ abstraction    
   | App Term Term                      -- ^ application    
   | Pi (Bind (TName, Embed Term) Term) -- ^ function type

   -- practical matters for surface language
   | Ann Term Term            -- ^ Annotated terms `( x : A )`   
   | Paren Term               -- ^ parenthesized term, useful for printing
   | Pos SourcePos Term       -- ^ marked source position, for error messages
     
   -- conveniences  
   | TrustMe Annot            -- ^ an axiom 'TRUSTME', inhabits all types 
   
   -- unit  
   | TyUnit                   -- ^ The type with a single inhabitant `One`
   | LitUnit                  -- ^ The inhabitant, written `tt`
     
   -- homework: boolean expressions
   | TyBool                   -- ^ The type with two inhabitants
   | LitBool Bool             -- ^ True and False
   | If Term Term Term Annot  -- ^ If expression for eliminating booleans

   -- homework sigma types 
   | Sigma (Bind (TName, Embed Term) Term)
     -- ^ sigma type `{ x : A | B }` 
   | Prod Term Term Annot
     -- ^ introduction for sigmas `( a , b )`
   | Pcase Term (Bind (TName, TName) Term) Annot
     -- ^ elimination form  `pcase p of (x,y) -> p`

   -- homework let expression
   | Let (Bind (TName, Embed Term) Term)
     -- ^ let expression, introduces a new (potentially recursive) 
     -- definition in the ctx


   -- propositional equality
   | TyEq Term Term     -- ^ Equality type  `a = b`
   | Refl Annot         -- ^ Proof of equality
   | Subst Term Term Annot
                        -- ^ equality elimination
   | Contra Term Annot  -- ^ witness to an equality contradiction

     
     
                 deriving (Show, Generic, Typeable)
               
-- | An 'Annot' is optional type information               
newtype Annot = Annot (Maybe Term) deriving (Show, Generic, Typeable)



-----------------------------------------
-- * Modules and declarations
-----------------------------------------

-- | A Module has a name, a list of imports, a list of declarations,
--   and a set of constructor names (which affect parsing).     
data Module = Module { moduleName         :: MName,
                       moduleImports      :: [ModuleImport],
                       moduleEntries      :: [Decl]
                       
                     }
              
  deriving (Show, Generic, Typeable)

newtype ModuleImport = ModuleImport MName
  deriving (Show,Eq, Generic, Typeable)



-- | Declarations are the components of modules
data Decl = Sig     TName  Term
           -- ^ Declaration for the type of a term
            
          | Def     TName  Term
            -- ^ The definition of a particular name, must 
            -- already have a type declaration in scope
            
          | RecDef TName Term 
            -- ^ A potentially (recursive) definition of 
            -- a particular name, must be declared 

            
  deriving (Show, Generic, Typeable)



-------------
-- * Auxiliary functions on syntax
-------------




-- | Default name for '_' occurring in patterns
wildcardName :: TName
wildcardName = string2Name "_"

-- | empty Annotation
noAnn :: Annot   
noAnn = Annot Nothing

-- | Partial inverse of Pos
unPos :: Term -> Maybe SourcePos
unPos (Pos p _) = Just p
unPos _         = Nothing

-- | Tries to find a Pos anywhere inside a term
unPosDeep :: Term -> Maybe SourcePos
unPosDeep = unPos -- something (mkQ Nothing unPos) -- TODO: Generic version of this

-- | Tries to find a Pos inside a term, otherwise just gives up.
unPosFlaky :: Term -> SourcePos
unPosFlaky t = fromMaybe (newPos "unknown location" 0 0) (unPosDeep t)



        
                          
-----------------
-- * Alpha equivalence, free variables and substitution.
------------------

{- We use the unbound library to mark the binding occurrences of
   variables in the syntax. That allows us to automatically derive
   functions for alpha-equivalence, free variables and substitution
   using the template haskell directives and default class instances 
   below. 
-}

-- Defining SourcePos abstractly means that they get ignored 
-- when comparing terms.
-- XXX need one with aeq' that always returns true.
$(makeClosedAlpha ''SourcePos)
-- instance Alpha SourcePos where
--   aeq' _ctx _ _ = True
--   fvAny' _ctx _nfn = pure
--   open _ _ = id
--   close _ _ = id
--   isPat _ = mempty
--   isTerm _ = True
--   nthPatFind _ _ = Left 0
--   namePatFind _ _ = Left 0
--   swaps' _ _ = id
--   freshen' _ x = return (x, mempty)
--   lfreshen' _ x cont = cont x mempty
  
instance Subst b SourcePos where subst _ _ = id ; substs _ = id

-- Among other things, the Alpha class enables the following
-- functions:
--    aeq :: Alpha a => a -> a -> Bool
--    fv  :: Alpha a => a -> [Name a]

instance Alpha Term where
  

instance Alpha Annot where
    -- override default behavior so that type annotations are ignored
    -- when comparing for alpha-equivalence
    aeq' _ _ _ = True

-- The subst class derives capture-avoiding substitution
-- It has two parameters because the sort of thing we are substiting
-- for may not be the same as what we are substituting into:

-- class Subst b a where
--    subst  :: Name b -> b -> a -> a       -- single substitution
--    substs :: [(Name b, b)] -> a -> a     -- multiple substitution

instance Subst Term Term where
  isvar (Var x) = Just (SubstName x)
  isvar _ = Nothing


instance Subst Term Annot
