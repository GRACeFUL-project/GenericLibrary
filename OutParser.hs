-- | Parser for the minizinc output.
-- Unsat not parsed into anything useful at the moment, the message
-- is returned as a string.
-- Assumes variables/labels outputted as
--    label or name : value
-- where value is either a boolean, integer or decimal number.
-- Example:
--    output ["pump cap : ", show(cap), "\noverflow : ", show(of)];
module OutParser (module OutParser) where

import Text.Parsec
import Text.ParserCombinators.Parsec.Number

type Parser a = Parsec String () a

type Label = String

type Solution = [(Label, Value)]

data Output
  = Sat [Solution] Solution
    -- ^ @[Solution]@ contains all solutions,
    -- @Solution@ is the optimal solution if it exists.
  | Unsat String
    -- ^ The unsat message.
  | ParseErr String
    -- ^ Parsec error message.
  deriving (Show, Eq)

data Value
  = B Bool
  | I Int
  | D Double
  deriving (Show, Eq)

(>>|) :: Monad m => m a -> b -> m b
a >>| b = a >> return b

-- | Parse @----------@
dash :: Parser ()
dash = string "----------" >>| ()

-- | Parse @==========@
equs :: Parser ()
equs = string "==========" >>| ()

-- | Parse a decimal number, e.g. @-0.2@, @1e10@ or @1.11@.
signedDouble :: Parser Double
signedDouble = sign <*> floating

-- | Parse a boolean @true@ or @false@.
bool :: Parser Bool
bool = (string "true" >>| True) <|> (string "false" >>| False)

-- | Parse boolean, integer or decimal output value.
value :: Parser Value
value = D <$> try signedDouble <|> I <$> try int <|> B <$> try bool

-- | Parse a label up to " : ".
-- Also consumes the " : " on successful parse.
lbl :: Parser Label
lbl = manyTill (alphaNum <|> space) (try (string " : "))

-- | Parse a line with label and its value.
var :: Parser (Label, Value)
var = do
  l <- lbl
  v <- value
  return (l, v)

-- | Parse a solution.
--
-- @
-- a : 3
-- b : true
-- ----------
-- @
--
-- results in
--
-- > [("a", I 3), ("b", B True)]
solution :: Parser [(Label, Value)]
solution = var `sepEndBy1` spaces <* dash

-- | Top level parser.
--
-- Parses all solutions produced.
--
-- @
-- a : true
-- b : 1
-- ----------
-- a : False
-- b : 2
-- ----------
-- ==========
-- @
--
-- results in
--
-- @
-- Sat [ [("a", B True), ("b", I 1)]
--     , [("a", B False), ("b", I 2)] ] -- All solutions.
--     [("a", B False), ("b", I 2)]     -- Optimal solution.
-- @
output :: Parser Output
output = try sat <|> unsat
  where
    sat = do
      sols <- solution `sepEndBy1` spaces
      optimal <- option [] (spaces >> equs >>| last sols)
      return $ Sat sols optimal
    unsat = Unsat <$> manyTill anyToken eof

-- | Run the top level parser.
--
-- @Parsec@ parse errors are wrapped in @ParseErr@.
par :: String -> Output
par s = case parse output "" s of
          Left err -> ParseErr $ show err
          Right out -> out

-- | Extracts the labels printed in the solutions.
--
-- Only looks at the first solution.
lbls :: Output -> [Label]
lbls (Sat (x:_) _) = map fst x
lbls _ = []

-- | Run @minizinc@ on the given input string and parse the result.
run :: String -> IO Output
run = undefined

-- | Run @minizinc@ on the given file path and parse the result.
runFile :: FilePath -> IO Output
runFile = undefined
