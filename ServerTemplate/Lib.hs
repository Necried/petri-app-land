{-# LANGUAGE QuasiQuotes #-}

module ServerTemplate.Lib where

import Text.RawString.QQ
import Data.Text as T

libHs :: T.Text
libHs = T.pack $ [r|{-# LANGUAGE OverloadedStrings #-}
module Static.Lib
    ( mainServer
    ) where

import           Control.Concurrent             (forkIO)
import           Control.Concurrent.Async       (race)
import           Control.Concurrent.STM         (TChan, atomically, readTChan,
                                                 writeTChan, STM)
import           Control.Monad                  (forever)
import           Control.Monad.IO.Class         (liftIO)
import qualified Data.Text              as T
import           Data.Text                      (Text)
import           Data.Text.IO                   as Tio
import           Network.HTTP.Types             (status400)
import           Network.Wai                    (Application, responseLBS)
import           Network.Wai.Handler.Warp       (run)
import           Network.Wai.Handler.WebSockets (websocketsOr)

import           Text.Read                      (readMaybe)
import qualified Network.WebSockets             as WS
import System.Environment (getArgs)

import qualified Static.ServerLogic as ServerLogic
import Static.ServerTypes
import Types
import Static.Decode
import Utils.Decode


wsApp :: TChan CentralMessage -> WS.ServerApp
wsApp centralMessageChan pendingConn = 
    let
        loop :: WS.Connection -> TChan ClientMessage -> IO ()
        loop conn clientMessageChan = do
                  -- wait for login message
                  rawMsg <- WS.receiveData conn
                  Tio.putStrLn $ T.concat ["Got login message:", rawMsg]
                  
                  case rawMsg of 
                    "v0.1" -> do -- tell the central thread to log the user in
                        atomically $ writeTChan centralMessageChan (ServerLogic.NewUser clientMessageChan conn)
                        return ()
                    _      -> do -- user's client version does not match 
                        WS.sendTextData conn ("ve" :: T.Text) --tell client that its version it wrong
                        return ()
    in
        do
        -- This function handles each new Connection.
        conn <- WS.acceptRequest pendingConn
        WS.forkPingThread conn 30

        -- Get a new message channel for this client.
        clientMessageChan <- atomically ServerLogic.newClientMessageChan

        loop conn clientMessageChan

fallbackApp :: Application
fallbackApp _ respond = respond $ responseLBS status400 [] "Not a WebSocket request."


app :: TChan CentralMessage -> Application
app chan = websocketsOr WS.defaultConnectionOptions (wsApp chan) fallbackApp


mainServer :: IO ()
mainServer = do
    args <- getArgs
    let port = if length args > 0 then (read $ (args !! 0) :: Int) else 8080
    centralMessageChan <- atomically ServerLogic.newCentralMessageChan
    forkIO $ ServerLogic.processCentralChan centralMessageChan
    Prelude.putStrLn $ "starting server on port " ++ show port
    run port (app centralMessageChan)|]