--------------------------------------------------------------------------------
-- | Implementation of Hakyll commands: build, preview...
{-# LANGUAGE CPP #-}
module Hakyll.Commands
    ( build
    , check
    , clean
    , preview
    , rebuild
    , server
    , deploy
    ) where


--------------------------------------------------------------------------------
import           Control.Monad              (when)
import           System.Directory           (doesDirectoryExist,
                                             removeDirectoryRecursive)
import           System.Exit                (exitWith)
import           System.Process             (system)


--------------------------------------------------------------------------------
import qualified Hakyll.Check               as Check
import           Hakyll.Core.Configuration
import           Hakyll.Core.Rules
import           Hakyll.Core.Runtime


--------------------------------------------------------------------------------
#ifdef PREVIEW_SERVER
import           Control.Applicative        ((<$>))
import           Control.Concurrent         (forkIO)
import qualified Data.Set                   as S
import           Hakyll.Core.Identifier
import           Hakyll.Core.Rules.Internal
import           Hakyll.Preview.Poll
import           Hakyll.Preview.Server
#endif


--------------------------------------------------------------------------------
-- | Build the site
build :: Configuration -> Rules a -> IO ()
build conf rules = do
    _ <- run conf rules
    return ()


--------------------------------------------------------------------------------
-- | Run the checker and exit
check :: Configuration -> IO ()
check config = Check.check config >>= exitWith


--------------------------------------------------------------------------------
-- | Remove the output directories
clean :: Configuration -> IO ()
clean conf = do
    remove $ destinationDirectory conf
    remove $ storeDirectory conf
  where
    remove dir = do
        putStrLn $ "Removing " ++ dir ++ "..."
        exists <- doesDirectoryExist dir
        when exists $ removeDirectoryRecursive dir


--------------------------------------------------------------------------------
-- | Preview the site
preview :: Configuration -> Rules a -> Int -> IO ()
#ifdef PREVIEW_SERVER
preview conf rules port = do
    -- Fork a thread polling for changes
    _ <- forkIO $ previewPoll conf update

    -- Run the server in the main thread
    server conf port
  where
    update = map toFilePath . S.toList . rulesResources <$> run conf rules
#else
preview _ _ _ = previewServerDisabled
#endif


--------------------------------------------------------------------------------
-- | Rebuild the site
rebuild :: Configuration -> Rules a -> IO ()
rebuild conf rules = do
    clean conf
    build conf rules


--------------------------------------------------------------------------------
-- | Start a server
server :: Configuration -> Int -> IO ()
#ifdef PREVIEW_SERVER
server conf port = do
    let destination = destinationDirectory conf
    staticServer destination preServeHook port
  where
    preServeHook _ = return ()
#else
server _ _ = previewServerDisabled
#endif


--------------------------------------------------------------------------------
-- | Upload the site
deploy :: Configuration -> IO ()
deploy conf = do
    _ <- system $ deployCommand conf
    return ()


--------------------------------------------------------------------------------
-- | Print a warning message about the preview serving not being enabled
#ifndef PREVIEW_SERVER
previewServerDisabled :: IO ()
previewServerDisabled =
    mapM_ putStrLn
        [ "PREVIEW SERVER"
        , ""
        , "The preview server is not enabled in the version of Hakyll. To"
        , "enable it, set the flag to True and recompile Hakyll."
        , "Alternatively, use an external tool to serve your site directory."
        ]
#endif
