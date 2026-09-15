module Main
    ( main
    ) where

import Data.Text (Text, empty)
import GHC.Types.SrcLoc (SrcSpan)
import Prelude (Either, IO, putStrLn)

import Tadka (Span)
import Tadka.Interop.GHC (SrcSpanConvError, spanFromSrcSpan)
import Tadka.GHC ()

interopBoundary
    :: Text
    -> SrcSpan
    -> Either SrcSpanConvError Span
interopBoundary = spanFromSrcSpan

main :: IO ()
main = do
    let _ = interopBoundary empty
    putStrLn "tadka-ghc: Phase 1 Tadka dependency boundary"
