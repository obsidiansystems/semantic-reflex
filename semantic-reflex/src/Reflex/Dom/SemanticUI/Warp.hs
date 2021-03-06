{-# LANGUAGE TemplateHaskell #-}

-- | This module is to help with fast development cycles. Use 'server' or
-- 'daemon' to start a warp server on the given port where you can see your
-- app.
module Reflex.Dom.SemanticUI.Warp where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 (unpack)
import Control.Lens ((^.))
import Control.Monad (void)
import Data.Text (Text)
import Language.Javascript.JSaddle
import Language.Javascript.JSaddle.WebSockets
import Network.Wai.Handler.Warp
import Network.Wai.Application.Static
import Network.Wai
import Network.WebSockets

import Data.FileEmbed

-- | Start the warp server
server :: Int -> ByteString -> JSM () -> Maybe FilePath -> IO ()
server port css app mstatic = do
  putStrLn $ "starting warp server: http://localhost:" ++ show port
  runApp css port app mstatic id $ return ()

-- | Restart the warp server and tell any connected clients to refresh
daemon :: Int -> ByteString -> JSM () -> Maybe FilePath -> IO ()
daemon port css app mstatic = do
--  debug port app
  debugWrapper (runApp css port app mstatic)
  putStrLn $ "restarting warp server: http://localhost:" ++ show port

-- | We serve the standard jsaddle-warp app but with a static server for the
-- javascript, css, and theme folder.
runApp :: ByteString -> Int -> JSM () -> Maybe FilePath -> Middleware -> JSM () -> IO ()
runApp css port mainApp mUserFilePath middleware preApp = do
  jsaddle <- jsaddleWithAppOr defaultConnectionOptions
    (preApp >> app) (middleware static)
  runSettings settings jsaddle
  where
    settings = setPort port $ setTimeout 3600 defaultSettings
    app = makeHead css >> mainApp >> syncPoint
    static = staticApp $ (defaultFileServerSettings
      $(strToExp =<< makeRelativeToProject "data/static"))
        { ss404Handler = mUserStatic }
    mUserStatic = fmap (staticApp . defaultFileServerSettings) mUserFilePath

-- Needed for non js targets, since the js-sources in the cabal file are not
-- linked
makeHead :: ByteString -> JSM ()
makeHead css = do

  document <- jsg ("document" :: Text)

  -- Push the css into a style tag
  style <- document ^. js1 ("createElement" :: Text) ("style" :: Text)
  style ^. jss ("innerText" :: Text) (unpack css)
  void $ document ^. js ("head" :: Text) ^. js1 ("appendChild" :: Text) style

  semanticCSS <- document ^. js1 ("createElement" :: Text) ("link" :: Text)
  semanticCSS ^. jss ("rel" :: Text) ("stylesheet" :: Text)
  semanticCSS ^. jss ("type" :: Text) ("text/css" :: Text)
  semanticCSS ^. jss ("href" :: Text) ("/semantic.min.css" :: Text)
  void $ document ^. js ("head" :: Text) ^. js1 ("appendChild" :: Text) semanticCSS

