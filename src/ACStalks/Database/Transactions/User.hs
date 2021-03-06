module ACStalks.Database.Transactions.User (
    getUser,
    getUserByUsername,
    updateUser,
    deleteUserByUid,
    insertUser
) where

import ACStalks.Schema.User
import ACStalks.Database.Transactions.Utils
import ACStalks.Database.DatabaseConnection
import qualified Data.Char as C
import Data.String.Interpolate ( i )
import qualified Data.Text as T
import Database.HDBC

table = schema "Users" 

userConstructor user = User { userName            = fromSql $ (user !! 0)  
                            , userNickname        = fromSql $ (user !! 1)  
                            , userPasshash        = fromSql $ (user !! 2)  
                            , userSecurityAnswer  = fromSql $ (user !! 3)  
                            , userSwitchFc        = fromSql $ (user !! 4)  
                            , userDodoCode        = fromSql $ (user !! 5)  
                            , userIslandOpen      = read $ fromSql $ (user !! 6)  
                            , userIslandOpenTime  = fromSql $ (user !! 7) 
                            , userBio             = fromSql $ (user !! 8)
                            , userFavVillager     = fromSql $ (user !! 9)
                            , userFavThing        = fromSql $ (user !! 10) 
                            , userNativeFruit     = fromSql $ (user !! 11) 
                            }

validateUser :: User -> IO (Status) -> IO (Status)
validateUser user valid =     
    if (T.length $ userName user) == 0 then return (Failure "username is empty")
    else if length (filter (not . C.isAlphaNum) $ T.unpack $ userName user) > 0 then return (Failure "username is not alphanum")
    else valid

getUser :: DatabaseConnection -> Int -> IO (Maybe User)
getUser dbc@(SqlConnection {}) uid =
    do
        results <- sqlQuery dbc
                   [i|

SELECT Username, Nickname, PassHash,             
       SecurityAnswer, SwitchFC, DodoCode,       
       IslandOpen, IslandOpenTime, Bio,          
       FavVillager, FavThing, NativeFruit        
FROM #{table} 
WHERE UserID = ? 

                   |]
                   [ toSql uid ] 

        if (length results == 0) 
        then return Nothing
        else let user = results !! 0
             in return (Just (userConstructor user) { userId = uid } ) 

 
getUserByUsername :: DatabaseConnection -> T.Text -> IO (Maybe User)
getUserByUsername dbc@(SqlConnection {}) username =
    do
        results <- sqlQuery dbc
                   [i| 

SELECT Username, Nickname, PassHash,       
       SecurityAnswer, SwitchFC, DodoCode, 
       IslandOpen, IslandOpenTime, Bio,    
       FavVillager, FavThing, NativeFruit,

       UserID       
FROM #{table} 
WHERE Username = ?;

                   |]
                   [ toSql $ T.toLower username ] 

        if (length results == 0) 
        then return Nothing
        else let user = results !! 0
             in return (Just (userConstructor user) { userId = fromSql $ user !! 12 } ) 
        

updateUser :: DatabaseConnection -> User -> IO (Status)
updateUser dbc@(SqlConnection {}) user = validateUser user $
    do
        rows <- sqlExec dbc
                [i|

UPDATE #{table}
SET   Username = ?,       
      Nickname = ?,       
      PassHash = ?,       
      SecurityAnswer = ?, 
      SwitchFC = ?,       
      DodoCode = ?,       
      IslandOpen  = ?,    
      IslandOpenTime = ?, 
      Bio = ?,            
      FavVillager = ?,    
      FavThing = ?,       
      NativeFruit = ?
WHERE UserID = ?

                |]
                [ toSql $ T.toLower $ userName user
                , toSql $ userNickname user
                , toSql $ userPasshash user
                , toSql $ userSecurityAnswer user
                , toSql $ userSwitchFc user
                , toSql $ userDodoCode user
                , toSql $ show $ userIslandOpen user
                , toSql $ userIslandOpenTime user
                , toSql $ userBio user
                , toSql $ userFavVillager user
                , toSql $ userFavThing user
                , toSql $ userNativeFruit user
                , toSql $ userId user
                ]
         
        if rows > 0  
        then return (Success)
        else return (Failure "")

deleteUserByUid :: DatabaseConnection -> Int -> IO (Status)
deleteUserByUid dbc@(SqlConnection {}) uid =
    do
        rows <- sqlExec dbc
                [i|

DELETE FROM #{table}
WHERE UserID = ?

                |]
                [ toSql $ uid ]
        
        if rows > 0  
        then return (Success)
        else return (Failure "")


insertUser :: DatabaseConnection -> User -> IO (Status)
insertUser dbc@(SqlConnection {}) user = validateUser user $
    do
        existing <- getUserByUsername dbc (userName user)
        
        case existing of
            Just _  -> return (Failure "existing username")
            Nothing -> do        
                rows <- sqlExec dbc
                        [i| 

INSERT INTO #{table} 
     (UserID,                 
      Username,               
      Nickname,               
      PassHash,               
      SecurityAnswer,         
      SwitchFC,               
      DodoCode,               
      IslandOpen,             
      IslandOpenTime,         
      Bio,                    
      FavVillager,            
      FavThing,               
      NativeFruit
    ) VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?)

                        |]
                        [ toSql $ T.toLower $ userName user
                        , toSql $ userNickname user
                        , toSql $ userPasshash user
                        , toSql $ userSecurityAnswer user
                        , toSql $ userSwitchFc user
                        , toSql $ userDodoCode user
                        , toSql $ show $ userIslandOpen user
                        , toSql $ userIslandOpenTime user
                        , toSql $ userBio user
                        , toSql $ userFavVillager user
                        , toSql $ userFavThing user
                        , toSql $ userNativeFruit user
                        ]
                
                if rows > 0  
                then return (Success)
                else return (Failure "")

