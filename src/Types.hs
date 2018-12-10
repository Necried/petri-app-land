{-# LANGUAGE OverloadedStrings #-}

module Types where

import Data.Map as M
import Data.String
import qualified Data.Text as T


-- paper 1 will stick to messages arriving in order (websockets)
-- paper 2 will allow messages out of order (webrtc)

type ElmDocType = (ElmType,String,String) -- type and name for pattern matching and documentation
                                          -- doc string can be empty, but name string has to be legal Elm name

data ElmType = ElmIntRange Int Int -- upper and lower bounds (used for optimizing messages, etc.)
             | ElmFloatRange Double Double Int -- upper and lower bounds, and number of decimal places of precision
             | ElmString -- a unicode string
             | ElmSizedString Int -- string with maximum size, and restricted character set TBD
             | ElmPair ElmDocType ElmDocType
             | ElmTriple ElmDocType ElmDocType ElmDocType
             | ElmList ElmDocType
             | ElmDict ElmDocType ElmDocType
             | ElmType String --the type referenced must be included in the map
             | ElmWildcardType String -- a type parameter
             | ElmMaybe ElmDocType
             | ElmBool
             | ElmResult ElmDocType ElmDocType
  deriving (Ord,Eq,Show)

type Constructor = (String,[ElmDocType]) -- (name, arguments)

data ElmCustom = ElmCustom String [Constructor] -- name of the type 
  deriving (Ord,Eq,Show)

type ServerState        = Constructor
data OutgoingClientMessage   = 
      ToSender            Constructor                   --reply back to the client that sent the orignal message
    | ToAllExceptSender   Constructor                   --not used
    | ToSenderAnd         Constructor                   --reply to sender and a set of other clients
    | ToSet               Constructor                   --reply to sender and a set of other clients
    | ToAll               Constructor                   --send a message to all connected clients
    | OneOf               [OutgoingClientMessage]       --send one of a list of possible messages
    | AllOf               [OutgoingClientMessage]       --send all of a list of possible messages
    | NoClientMessage
  deriving (Ord,Eq,Show)
type ClientTransition   = Constructor
type ClientCmd          = Constructor
type ServerTransition   = Constructor
type ServerCmd          = Constructor

type ClientStateDiagram =
    M.Map (String, ClientTransition) (String, Maybe ClientCmd, Maybe ServerTransition)

type ServerStateDiagram =
    M.Map (String, ServerTransition) (String, Maybe ServerCmd, OutgoingClientMessage)

data Place =
    Place 
        T.Text      --name of the place
        [ElmDocType] --place state
        [ElmDocType] --player state at this place

data NetTransition =
    NetTransition
        (M.Map
            (T.Text, Constructor)   --from place (must appear in map above), message which attempts to fire this transition (must be unique)
            T.Text                  --to place (must appear in map above)
        )
        OutgoingClientMessage       --message to send if this transition is fired
        (Maybe ServerCmd)           --whether to issue a command when this transition is fired

-- a net describing a collections of places and transitions
data ServerNet = 
    ServerNet
        T.Text              --net name
        [Place]             --all the places in this net
        [NetTransition]     --transitions between the places
        


type ExtraClientTypes =
    [ElmCustom]

type ExtraServerTypes =
    [ElmCustom]

data ClientState =
      ClientState Constructor
    | ClientStateWithSubs Constructor [Constructor] {-subs-}

type ClientServerApp =
    ( (String, Maybe Constructor)       --starting state and command of client
    , (String, Maybe Constructor)       --starting state of server
    , [ClientState]                     --all possible client states
    , [ServerState]                     --all possible server states
    , ExtraClientTypes                  --extra client types used in states or messages
    , ExtraServerTypes                  --extra server types used in states or messages
    , ClientStateDiagram                --the client state diagram
    , ServerStateDiagram                --the client state diagram
    , [Plugin]                          --a list of plugins to be installed
    )

data Plugin = 
      Plugin String {-name-}
    | PluginGen String {-name-} (IO [(FilePath,T.Text)]) {-function to generate the plugin-}