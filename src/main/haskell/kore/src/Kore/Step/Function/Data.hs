{-|
Module      : Kore.Step.Function.Data
Description : Data structures used for function evaluation.
Copyright   : (c) Runtime Verification, 2018
License     : NCSA
Maintainer  : virgil.serbanuta@runtimeverification.com
Stability   : experimental
Portability : portable
-}
module Kore.Step.Function.Data
    ( BuiltinAndAxiomSimplifier (..)
    , BuiltinAndAxiomSimplifierMap
    , AttemptedAxiom (..)
    , AttemptedAxiomResults (..)
    , CommonAttemptedAxiom
    , applicationAxiomSimplifier
    , notApplicableAxiomEvaluator
    , purePatternAxiomEvaluator
    ) where

import           Control.DeepSeq
                 ( NFData )
import qualified Data.Map.Strict as Map
import           GHC.Generics
                 ( Generic )

import           Kore.AST.Pure
import           Kore.AST.Valid
import           Kore.IndexedModule.MetadataTools
                 ( MetadataTools )
import           Kore.Step.OrOfExpandedPattern
                 ( OrOfExpandedPattern, makeFromSinglePurePattern )
import qualified Kore.Step.OrOfExpandedPattern as OrOfExpandedPattern
                 ( make, merge )
import           Kore.Step.Pattern
import           Kore.Step.Simplification.Data
                 ( PredicateSubstitutionSimplifier, SimplificationProof (..),
                 Simplifier, StepPatternSimplifier )
import           Kore.Step.StepperAttributes
                 ( StepperAttributes )
import           Kore.Unparser
import           Kore.Variables.Fresh
                 ( FreshVariable )

{-| 'BuiltinAndAxiomSimplifier' simplifies 'Application' patterns using either
an axiom or builtin code.

Arguments:

* 'MetadataTools' are tools for finding additional information about
patterns such as their sorts, whether they are constructors or hooked.

* 'StepPatternSimplifier' is a Function for simplifying patterns, used for
the post-processing of the function application results.

* 'Application' is the pattern to be evaluated.

Return value:

It returns the result of appling the function, together with a proof certifying
that the function was applied correctly (which is only a placeholder right now).
-}
newtype BuiltinAndAxiomSimplifier level =
    BuiltinAndAxiomSimplifier
        (forall variable
        .   ( FreshVariable variable
            , MetaOrObject level
            , Ord (variable level)
            , OrdMetaOrObject variable
            , SortedVariable variable
            , Show (variable level)
            , Show (variable Object)
            , Unparse (variable level)
            , ShowMetaOrObject variable
            )
        => MetadataTools level StepperAttributes
        -> PredicateSubstitutionSimplifier level Simplifier
        -> StepPatternSimplifier level variable
        -> StepPattern level variable
        -> Simplifier
            ( AttemptedAxiom level variable
            , SimplificationProof level
            )
        )

{-|A type to abstract away the mapping from symbol identifiers to
their corresponding evaluators.
-}
type BuiltinAndAxiomSimplifierMap level =
    Map.Map (Id level) (BuiltinAndAxiomSimplifier level)

{-| A type holding the result of applying an axiom to a pattern.
-}
data AttemptedAxiomResults level variable =
    AttemptedAxiomResults
        { results :: !(OrOfExpandedPattern level variable)
        -- ^ The result of applying the axiom
        , remainders :: !(OrOfExpandedPattern level variable)
        -- ^ The part of the pattern that was not rewritten by the axiom.
        }
  deriving (Eq, Generic, Show)

instance (NFData (variable level))
    => NFData (AttemptedAxiomResults level variable)

instance (Ord level, Ord (variable level))
    => Semigroup (AttemptedAxiomResults level variable)
  where
    (<>)
        AttemptedAxiomResults
            { results = firstResults
            , remainders = firstRemainders
            }
        AttemptedAxiomResults
            { results = secondResults
            , remainders = secondRemainders
            }
      =
        AttemptedAxiomResults
            { results = OrOfExpandedPattern.merge firstResults secondResults
            , remainders =
                    OrOfExpandedPattern.merge firstRemainders secondRemainders
            }

instance (Ord level, Ord (variable level))
    => Monoid (AttemptedAxiomResults level variable)
  where
    mempty =
        AttemptedAxiomResults
            { results = OrOfExpandedPattern.make []
            , remainders = OrOfExpandedPattern.make []
            }

{-| 'AttemptedAxiom' holds the result of axiom-based simplification, with
a case for axioms that can't be applied.
-}
data AttemptedAxiom level variable
    = NotApplicable
    | Applied !(AttemptedAxiomResults level variable)
  deriving (Eq, Generic, Show)

instance (NFData (variable level))
    => NFData (AttemptedAxiom level variable)

{-| 'CommonAttemptedAxiom' particularizes 'AttemptedAxiom' to 'Variable',
following the same pattern as the other `Common*` types.
-}
type CommonAttemptedAxiom level = AttemptedAxiom level Variable

-- |Yields a pure 'Simplifier' which always returns 'NotApplicable'
notApplicableAxiomEvaluator
    :: Simplifier
        (AttemptedAxiom level1 variable, SimplificationProof level2)
notApplicableAxiomEvaluator = pure (NotApplicable, SimplificationProof)

-- |Yields a pure 'Simplifier' which produces a given 'StepPattern'
purePatternAxiomEvaluator
    :: (MetaOrObject level, Ord (variable level))
    => StepPattern level variable
    -> Simplifier
        (AttemptedAxiom level variable, SimplificationProof level)
purePatternAxiomEvaluator p =
    pure
        ( Applied AttemptedAxiomResults
            { results = makeFromSinglePurePattern p
            , remainders = OrOfExpandedPattern.make []
            }
        , SimplificationProof
        )

{-| Creates an 'BuiltinAndAxiomSimplifier' from a similar function that takes an
'Application'.
-}
applicationAxiomSimplifier
    :: forall level
    .   ( forall variable
        .   ( FreshVariable variable
            , MetaOrObject level
            , Ord (variable level)
            , OrdMetaOrObject variable
            , SortedVariable variable
            , Show (variable level)
            , Show (variable Object)
            , Unparse (variable level)
            , ShowMetaOrObject variable
            )
        => MetadataTools level StepperAttributes
        -> PredicateSubstitutionSimplifier level Simplifier
        -> StepPatternSimplifier level variable
        -> CofreeF
            (Application level)
            (Valid (variable level) level)
            (StepPattern level variable)
        -> Simplifier
            ( AttemptedAxiom level variable
            , SimplificationProof level
            )
        )
    -> BuiltinAndAxiomSimplifier level
applicationAxiomSimplifier applicationSimplifier =
    BuiltinAndAxiomSimplifier helper
  where
    helper
        ::  ( forall variable
            .   ( FreshVariable variable
                , MetaOrObject level
                , Ord (variable level)
                , OrdMetaOrObject variable
                , SortedVariable variable
                , Show (variable level)
                , Show (variable Object)
                , Unparse (variable level)
                , ShowMetaOrObject variable
                )
            => MetadataTools level StepperAttributes
            -> PredicateSubstitutionSimplifier level Simplifier
            -> StepPatternSimplifier level variable
            -> StepPattern level variable
            -> Simplifier
                ( AttemptedAxiom level variable
                , SimplificationProof level
                )
        )
    helper
        tools
        substitutionSimplifier
        simplifier
        patt
      =
        case fromPurePattern patt of
            (valid :< ApplicationPattern p) ->
                applicationSimplifier
                    tools substitutionSimplifier simplifier (valid :< p)
            _ -> error
                ("Expected an application pattern, but got: " ++ show patt)

