module ACStalks.Database.Transactions.Price (
    PriceSortOrder(..),

    deletePriceByUid,
    insertPrice,
    getPriceByUid,
    getNPrices
) where

import ACStalks.Schema.Price
import ACStalks.Schema.User
import ACStalks.Database.Transactions.Utils
import ACStalks.Database.DatabaseConnection
import Data.String.Interpolate ( i )
import qualified Data.Text as T
import qualified Data.Time as Time
import Database.HDBC

table = schema "Prices" 
usersTable = schema "Users" 

data PriceSortOrder = PriceAscending | PriceDescending

priceConstructor :: [SqlValue] -> Price
priceConstructor p = Price { priceId             = fromSql $ (p !! 0)
                           , price               = fromSql $ (p !! 1)
                           , priceTime           = fromSql $ (p !! 2)
                           , priceTimezone       = read $ fromSql $ (p !! 3)
                           , priceUserId         = fromSql $ (p !! 4)
                           }

validatePrice :: Price -> IO (Status) -> IO (Status)
validatePrice p valid = 
    if      (price p < 0) then return (Failure "negative price")
    else if (price p > 9999) then return (Failure "price max reached")
    else valid

deletePriceByUid :: DatabaseConnection -> Int -> IO (Int)
deletePriceByUid dbc@(SqlConnection {}) uid = 
    sqlExec dbc
    ( "DELETE FROM " ++ table ++
    " WHERE UserID = ?") [ toSql $ uid ]


getPriceByUid :: DatabaseConnection -> Int -> IO (Maybe Price)
getPriceByUid dbc@(SqlConnection {}) uid =
    do
        results <- sqlQuery dbc
                   ( "SELECT                                    \
                    \ PriceID, Price, PriceTime,                \
                    \ PriceTimezone, UserID                     \
                    \ FROM " ++ table ++ " WHERE UserID = ?     \
                    \ ORDER BY PriceID DESC")
                   [ toSql $ uid ] 

        if (length results == 0) 
        then return Nothing
        else let p = results !! 0
             in return (Just (priceConstructor p))

getNPrices :: DatabaseConnection -> Int -> PriceSortOrder -> IO ([Price])
getNPrices dbc@(SqlConnection {}) n o =
    do
        results <- sqlQuery dbc
                   [i| 

SELECT MAX(PriceID)
     , Price
     , PriceTime
     , PriceTimezone
     , UserID
FROM #{table}
GROUP BY UserID
ORDER BY Price #{sqlOrder o}
LIMIT #{n}

                   |]         
                   []
        return (map priceConstructor results) 
    where
        sqlOrder PriceAscending = "ASC"
        sqlOrder PriceDescending = "DESC"

 
insertPrice :: DatabaseConnection -> Price -> IO (Status)
insertPrice dbc@(SqlConnection {}) p = validatePrice p $
    do
        rows <- sqlExec dbc
                (  "INSERT INTO " ++ table ++ "    \
                  \ (PriceID,                      \
                  \  Price,                        \
                  \  PriceTime,                    \
                  \  PriceTimezone,                \
                  \  UserID) VALUES (NULL,?,?,?,?);")
                [ toSql $ price p 
                , toSql $ priceTime p
                , toSql $ Time.timeZoneOffsetString $ priceTimezone p
                , toSql $ priceUserId p ]
        
        if rows > 0  
        then return (Success)
        else return (Failure "")
